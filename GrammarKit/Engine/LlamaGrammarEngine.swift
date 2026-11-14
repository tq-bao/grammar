import Foundation
import llama

/// Sửa ngữ pháp bằng llama.cpp chạy trên máy (Metal).
///
/// Mọi lời gọi C API đều nằm trong actor này nên không bao giờ chạy song song.
public actor LlamaGrammarEngine: GrammarEngine {
    public struct Configuration: Sendable {
        public var contextSize: UInt32 = 2048
        public var gpuLayers: Int32 = -1  // âm = toàn bộ layer lên GPU
        public init() {}
    }

    /// Sở hữu các con trỏ C và giải phóng chúng khi engine bị huỷ.
    /// Chỉ được dùng bên trong actor nên đánh dấu @unchecked Sendable là an toàn.
    private final class Handles: @unchecked Sendable {
        let model: OpaquePointer
        let context: OpaquePointer
        let sampler: UnsafeMutablePointer<llama_sampler>

        init(model: OpaquePointer, context: OpaquePointer, sampler: UnsafeMutablePointer<llama_sampler>) {
            self.model = model
            self.context = context
            self.sampler = sampler
        }

        deinit {
            llama_sampler_free(sampler)
            llama_free(context)
            llama_model_free(model)
        }
    }

    private let handles: Handles
    private let vocab: OpaquePointer
    private let template: String?

    /// Token của prompt cố định đang nằm trong KV cache (rỗng = chưa có).
    private var cachedPrefix: [llama_token] = []
    private var fixedPrefix: [llama_token]?

    private var context: OpaquePointer { handles.context }
    private var sampler: UnsafeMutablePointer<llama_sampler> { handles.sampler }

    public let modelURL: URL

    private static let backendInit: Void = {
        // Tắt log của llama.cpp/ggml để không làm rối console.
        llama_log_set({ _, _, _ in }, nil)
        llama_backend_init()
    }()

    public init(modelURL: URL, configuration: Configuration = .init()) throws {
        _ = Self.backendInit
        self.modelURL = modelURL

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = configuration.gpuLayers
        guard let model = llama_model_load_from_file(modelURL.path, modelParams) else {
            throw GrammarEngineError.modelLoadFailed(modelURL.path)
        }

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = configuration.contextSize
        ctxParams.n_batch = configuration.contextSize
        ctxParams.no_perf = true
        guard let context = llama_init_from_model(model, ctxParams) else {
            llama_model_free(model)
            throw GrammarEngineError.contextCreationFailed
        }

        var samplerParams = llama_sampler_chain_default_params()
        samplerParams.no_perf = true
        let sampler = llama_sampler_chain_init(samplerParams)!
        // temperature = 0: luôn chọn token có xác suất cao nhất.
        llama_sampler_chain_add(sampler, llama_sampler_init_greedy())

        self.handles = Handles(model: model, context: context, sampler: sampler)
        self.vocab = llama_model_get_vocab(model)
        self.template = llama_model_chat_template(model, nil).map { String(cString: $0) }
    }

    /// Chạy một câu để nạp shader/bộ nhớ, giúp lần kiểm tra đầu tiên nhanh hơn.
    public func warmUp() async {
        _ = try? await correct("This are a warm up sentence.")
    }

    public func correct(_ sentence: String) async throws -> String {
        let prompt = try applyTemplate(GrammarPrompt.messages(for: sentence), addAssistant: true)
        let promptTokens = try tokenize(prompt, addSpecial: true)
        let sentenceTokenCount = try tokenize(sentence, addSpecial: false).count
        let maxTokens = sentenceTokenCount * 2 + 16

        llama_sampler_reset(sampler)
        do {
            try prefill(promptTokens)
        } catch {
            cachedPrefix = []
            throw error
        }

        var outputBytes: [UInt8] = []
        var pieceBuffer = [CChar](repeating: 0, count: 256)

        for _ in 0..<maxTokens {
            try Task.checkCancellation()

            var token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) { break }

            let length = llama_token_to_piece(vocab, token, &pieceBuffer, Int32(pieceBuffer.count), 0, false)
            if length > 0 {
                outputBytes.append(contentsOf: pieceBuffer[0..<Int(length)].map { UInt8(bitPattern: $0) })
            }
            // Output chỉ có một dòng: gặp xuống dòng sau khi đã có nội dung thì dừng sớm.
            if outputBytes.contains(0x0A),
               !String(decoding: outputBytes, as: UTF8.self)
                   .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                break
            }

            let result = withUnsafeMutablePointer(to: &token) { pointer in
                llama_decode(context, llama_batch_get_one(pointer, 1))
            }
            guard result == 0 else {
                cachedPrefix = []
                throw GrammarEngineError.decodeFailed(result)
            }
        }

        let raw = String(decoding: outputBytes, as: UTF8.self)
        return OutputSanitizer.clean(raw, original: sentence)
    }

    // MARK: - Helpers

    /// Đưa prompt vào KV cache, dùng lại phần prompt cố định (system + ví dụ) nếu đã có sẵn.
    ///
    /// Phần cố định chiếm phần lớn số token. Giữ nó trong KV cache giữa các lần gọi
    /// giúp mỗi lần kiểm tra chỉ phải xử lý phần câu mới.
    private func prefill(_ promptTokens: [llama_token]) throws {
        let memory = llama_get_memory(context)
        var start = 0

        if !cachedPrefix.isEmpty, promptTokens.starts(with: cachedPrefix), cachedPrefix.count < promptTokens.count {
            // Xoá phần sau prefix (câu cũ và output cũ), giữ lại prefix.
            llama_memory_seq_rm(memory, 0, Int32(cachedPrefix.count), -1)
            start = cachedPrefix.count
        } else {
            llama_memory_clear(memory, true)
            cachedPrefix = []
            let prefix = try fixedPrefixTokens()
            if promptTokens.starts(with: prefix), prefix.count < promptTokens.count {
                try decode(prefix[...])
                cachedPrefix = prefix
                start = prefix.count
            }
        }
        try decode(promptTokens[start...])
    }

    private func decode(_ tokens: ArraySlice<llama_token>) throws {
        var tokens = Array(tokens)
        let result = tokens.withUnsafeMutableBufferPointer { buffer in
            llama_decode(context, llama_batch_get_one(buffer.baseAddress, Int32(buffer.count)))
        }
        guard result == 0 else { throw GrammarEngineError.decodeFailed(result) }
    }

    /// Token của phần prompt không đổi giữa các câu: system prompt và các ví dụ mẫu.
    private func fixedPrefixTokens() throws -> [llama_token] {
        if let fixedPrefix { return fixedPrefix }
        let messages = Array(GrammarPrompt.messages(for: "").dropLast())
        let text = try applyTemplate(messages, addAssistant: false)
        let tokens = try tokenize(text, addSpecial: true)
        fixedPrefix = tokens
        return tokens
    }

    private func applyTemplate(_ messages: [GrammarPrompt.Message], addAssistant: Bool) throws -> String {
        // Giữ C string sống trong suốt lời gọi, giải phóng sau đó.
        let roles = messages.map { strdup($0.role.rawValue)! }
        let contents = messages.map { strdup($0.content)! }
        defer {
            roles.forEach { free($0) }
            contents.forEach { free($0) }
        }
        let chat = zip(roles, contents).map { llama_chat_message(role: $0, content: $1) }
        let estimated = messages.reduce(0) { $0 + $1.content.utf8.count } * 2 + 512
        var buffer = [CChar](repeating: 0, count: estimated)

        func apply(_ buffer: inout [CChar]) -> Int32 {
            chat.withUnsafeBufferPointer { chatPointer in
                if let template {
                    template.withCString { tmpl in
                        llama_chat_apply_template(tmpl, chatPointer.baseAddress, chat.count, addAssistant, &buffer, Int32(buffer.count))
                    }
                } else {
                    llama_chat_apply_template(nil, chatPointer.baseAddress, chat.count, addAssistant, &buffer, Int32(buffer.count))
                }
            }
        }

        var length = apply(&buffer)
        if length > Int32(buffer.count) {
            buffer = [CChar](repeating: 0, count: Int(length) + 1)
            length = apply(&buffer)
        }
        guard length > 0 else { throw GrammarEngineError.promptTemplateFailed }
        return String(decoding: buffer[0..<Int(length)].map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private func tokenize(_ text: String, addSpecial: Bool) throws -> [llama_token] {
        let utf8Count = Int32(text.utf8.count)
        var tokens = [llama_token](repeating: 0, count: Int(utf8Count) + 16)
        var count = llama_tokenize(vocab, text, utf8Count, &tokens, Int32(tokens.count), addSpecial, true)
        if count < 0 {
            tokens = [llama_token](repeating: 0, count: Int(-count))
            count = llama_tokenize(vocab, text, utf8Count, &tokens, Int32(tokens.count), addSpecial, true)
        }
        guard count >= 0 else { throw GrammarEngineError.tokenizeFailed }
        return Array(tokens.prefix(Int(count)))
    }
}
