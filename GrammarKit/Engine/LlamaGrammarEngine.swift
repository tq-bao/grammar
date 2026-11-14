import Foundation
import llama

/// Sửa ngữ pháp và dịch sang tiếng Việt bằng llama.cpp chạy trên máy (Metal).
///
/// Mọi lời gọi C API đều nằm trong actor này nên không bao giờ chạy song song.
public actor LlamaGrammarEngine: GrammarEngine, TranslationEngine {
    public struct Configuration: Sendable {
        public var contextSize: UInt32 = 2048
        public var gpuLayers: Int32 = -1  // âm = toàn bộ layer lên GPU
        public init() {}
    }

    /// Sở hữu con trỏ model và giải phóng khi không còn ai dùng.
    /// Chỉ được dùng bên trong actor nên đánh dấu @unchecked Sendable là an toàn.
    private final class Model: @unchecked Sendable {
        let pointer: OpaquePointer

        init(pointer: OpaquePointer) {
            self.pointer = pointer
        }

        deinit {
            llama_model_free(pointer)
        }
    }

    /// Một llama context cùng sampler và KV cache của phần prompt cố định.
    ///
    /// Mỗi loại prompt (sửa ngữ pháp, dịch) có phiên riêng, nên phần prompt cố định
    /// của loại này không bị loại kia xoá khỏi KV cache. Phiên giữ tham chiếu tới `Model`
    /// để model chỉ được giải phóng sau mọi context.
    private final class Session: @unchecked Sendable {
        let model: Model
        let context: OpaquePointer
        let sampler: UnsafeMutablePointer<llama_sampler>
        /// Dựng toàn bộ message cho một câu. Mọi message trừ message cuối là phần cố định.
        let messages: @Sendable (String) -> [GrammarPrompt.Message]
        /// Token của prompt cố định đang nằm trong KV cache (rỗng = chưa có).
        var cachedPrefix: [llama_token] = []
        var fixedPrefix: [llama_token]?

        init(
            model: Model,
            configuration: Configuration,
            messages: @escaping @Sendable (String) -> [GrammarPrompt.Message],
            bannedTokens: [llama_token] = []
        ) throws {
            var ctxParams = llama_context_default_params()
            ctxParams.n_ctx = configuration.contextSize
            ctxParams.n_batch = configuration.contextSize
            ctxParams.no_perf = true
            guard let context = llama_init_from_model(model.pointer, ctxParams) else {
                throw GrammarEngineError.contextCreationFailed
            }

            var samplerParams = llama_sampler_chain_default_params()
            samplerParams.no_perf = true
            let sampler = llama_sampler_chain_init(samplerParams)!
            if !bannedTokens.isEmpty {
                let vocab = llama_model_get_vocab(model.pointer)
                let biases = bannedTokens.map { llama_logit_bias(token: $0, bias: -Float.infinity) }
                llama_sampler_chain_add(
                    sampler, llama_sampler_init_logit_bias(llama_vocab_n_tokens(vocab), Int32(biases.count), biases))
            }
            // temperature = 0: luôn chọn token có xác suất cao nhất.
            llama_sampler_chain_add(sampler, llama_sampler_init_greedy())

            self.model = model
            self.context = context
            self.sampler = sampler
            self.messages = messages
        }

        deinit {
            llama_sampler_free(sampler)
            llama_free(context)
        }
    }

    private let model: Model
    private let configuration: Configuration
    private let vocab: OpaquePointer
    private let template: String?
    private let grammarSession: Session
    /// Phiên dịch, chỉ tạo ở lần dịch đầu tiên để ai không bật Dịch thì không tốn KV cache.
    private var translationSession: Session?

    public let modelURL: URL

    private static let backendInit: Void = {
        // Tắt log của llama.cpp/ggml để không làm rối console.
        llama_log_set({ _, _, _ in }, nil)
        llama_backend_init()
    }()

    public init(modelURL: URL, configuration: Configuration = .init()) throws {
        _ = Self.backendInit
        self.modelURL = modelURL
        self.configuration = configuration

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = configuration.gpuLayers
        guard let pointer = llama_model_load_from_file(modelURL.path, modelParams) else {
            throw GrammarEngineError.modelLoadFailed(modelURL.path)
        }
        let model = Model(pointer: pointer)

        self.model = model
        self.grammarSession = try Session(model: model, configuration: configuration, messages: GrammarPrompt.messages(for:))
        self.vocab = llama_model_get_vocab(pointer)
        self.template = llama_model_chat_template(pointer, nil).map { String(cString: $0) }
    }

    /// Chạy một câu để nạp shader/bộ nhớ, giúp lần kiểm tra đầu tiên nhanh hơn.
    public func warmUp() async {
        _ = try? await correct("This are a warm up sentence.")
    }

    public func correct(_ sentence: String) async throws -> String {
        let sentenceTokenCount = try tokenize(sentence, addSpecial: false).count
        let raw = try generate(in: grammarSession, for: sentence, maxTokens: sentenceTokenCount * 2 + 16)
        return OutputSanitizer.clean(raw, original: sentence)
    }

    /// Dịch câu tiếng Anh sang tiếng Việt. Dùng context riêng nên không làm mất
    /// KV cache của prompt sửa ngữ pháp.
    public func translate(_ sentence: String) async throws -> String {
        let session: Session
        if let existing = translationSession {
            session = existing
        } else {
            session = try Session(
                model: model, configuration: configuration, messages: TranslationPrompt.messages(for:),
                bannedTokens: nonLatinScriptTokens())
            translationSession = session
        }
        // Tiếng Việt có dấu tốn nhiều token hơn câu tiếng Anh tương ứng.
        let sentenceTokenCount = try tokenize(sentence, addSpecial: false).count
        let raw = try generate(in: session, for: sentence, maxTokens: sentenceTokenCount * 4 + 32)
        return try OutputSanitizer.cleanTranslation(raw)
    }

    /// Token mà phần chữ chứa ký tự Trung, Nhật hoặc Hàn. Bản dịch tiếng Việt không bao giờ cần chúng,
    /// nhưng model Qwen thỉnh thoảng trôi sang tiếng Trung giữa câu.
    private func nonLatinScriptTokens() -> [llama_token] {
        var banned: [llama_token] = []
        var buffer = [CChar](repeating: 0, count: 256)
        for token in 0..<llama_vocab_n_tokens(vocab) {
            let length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, true)
            guard length > 0,
                  let piece = String(validating: buffer[0..<Int(length)].map { UInt8(bitPattern: $0) }, as: UTF8.self)
            else { continue }
            if piece.unicodeScalars.contains(where: Self.isCJK) { banned.append(token) }
        }
        return banned
    }

    static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x2E80...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF, 0xFF00...0xFFEF, 0x20000...0x2FA1F: true
        default: false
        }
    }

    // MARK: - Sinh token

    /// Chạy prompt của `session` cho `sentence` và trả về text thô mô hình sinh ra.
    private func generate(in session: Session, for sentence: String, maxTokens: Int) throws -> String {
        let prompt = try applyTemplate(session.messages(sentence), addAssistant: true)
        let promptTokens = try tokenize(prompt, addSpecial: true)

        llama_sampler_reset(session.sampler)
        do {
            try prefill(promptTokens, in: session)
        } catch {
            session.cachedPrefix = []
            throw error
        }

        var outputBytes: [UInt8] = []
        var pieceBuffer = [CChar](repeating: 0, count: 256)

        for _ in 0..<maxTokens {
            try Task.checkCancellation()

            var token = llama_sampler_sample(session.sampler, session.context, -1)
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
                llama_decode(session.context, llama_batch_get_one(pointer, 1))
            }
            guard result == 0 else {
                session.cachedPrefix = []
                throw GrammarEngineError.decodeFailed(result)
            }
        }

        return String(decoding: outputBytes, as: UTF8.self)
    }

    // MARK: - Helpers

    /// Đưa prompt vào KV cache của `session`, dùng lại phần prompt cố định (system + ví dụ) nếu đã có sẵn.
    ///
    /// Phần cố định chiếm phần lớn số token. Giữ nó trong KV cache giữa các lần gọi
    /// giúp mỗi lần chạy chỉ phải xử lý phần câu mới.
    private func prefill(_ promptTokens: [llama_token], in session: Session) throws {
        let memory = llama_get_memory(session.context)
        var start = 0

        let cached = session.cachedPrefix
        if !cached.isEmpty, promptTokens.starts(with: cached), cached.count < promptTokens.count {
            // Xoá phần sau prefix (câu cũ và output cũ), giữ lại prefix.
            llama_memory_seq_rm(memory, 0, Int32(cached.count), -1)
            start = cached.count
        } else {
            llama_memory_clear(memory, true)
            session.cachedPrefix = []
            let prefix = try fixedPrefixTokens(for: session)
            if promptTokens.starts(with: prefix), prefix.count < promptTokens.count {
                try decode(prefix[...], in: session)
                session.cachedPrefix = prefix
                start = prefix.count
            }
        }
        try decode(promptTokens[start...], in: session)
    }

    private func decode(_ tokens: ArraySlice<llama_token>, in session: Session) throws {
        var tokens = Array(tokens)
        let result = tokens.withUnsafeMutableBufferPointer { buffer in
            llama_decode(session.context, llama_batch_get_one(buffer.baseAddress, Int32(buffer.count)))
        }
        guard result == 0 else { throw GrammarEngineError.decodeFailed(result) }
    }

    /// Token của phần prompt không đổi giữa các câu: system prompt và các ví dụ mẫu.
    private func fixedPrefixTokens(for session: Session) throws -> [llama_token] {
        if let fixed = session.fixedPrefix { return fixed }
        let messages = Array(session.messages("").dropLast())
        let text = try applyTemplate(messages, addAssistant: false)
        let tokens = try tokenize(text, addSpecial: true)
        session.fixedPrefix = tokens
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
