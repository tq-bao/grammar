import Foundation

/// Tìm file model GGUF: biến môi trường (dev/benchmark) → thư mục dữ liệu của người dùng
/// (model đã tải ở lần mở đầu tiên) → app bundle (bản build có kèm model).
public enum ModelLocator {
    /// Model mặc định, chọn theo kết quả GrammarBench (xem docs/model-benchmark.md).
    public static let defaultModelFileName = "Qwen2.5-7B-Instruct-Q4_K_M.gguf"

    /// Nơi tải model mặc định. Ghim theo commit 8911e8a của repo bartowski/Qwen2.5-7B-Instruct-GGUF
    /// để file trên Hugging Face không bị thay mà app không biết.
    public static let defaultModelURL = URL(
        string: "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/8911e8a47f92bac19d6f5c64a2e2095bd2f7d031/Qwen2.5-7B-Instruct-Q4_K_M.gguf"
    )!

    /// SHA256 và kích thước của model mặc định (khớp `x-linked-etag`/`x-linked-size` trên Hugging Face).
    public static let defaultModelSHA256 = "65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423"
    public static let defaultModelSize: Int64 = 4_683_074_240

    /// Thư mục chứa model (trong bundle là `Contents/Resources/Models`,
    /// trong dữ liệu người dùng là `Application Support/Grammar/Models`).
    public static let modelsDirectoryName = "Models"

    /// Tên thư mục của app trong Application Support.
    public static let applicationSupportFolderName = "Grammar"

    /// Biến môi trường để chỉ định đường dẫn model khi dev/benchmark.
    public static let environmentKey = "GRAMMAR_MODEL_PATH"

    /// `~/Library/Application Support/Grammar/Models`.
    public static func applicationSupportModelsDirectory() -> URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return nil }
        return base
            .appendingPathComponent(applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent(modelsDirectoryName, isDirectory: true)
    }

    /// Nơi lưu model tải về.
    public static func downloadDestination(
        fileName: String = defaultModelFileName,
        modelsDirectory: URL? = applicationSupportModelsDirectory()
    ) -> URL? {
        modelsDirectory?.appendingPathComponent(fileName)
    }

    public static func locate(
        fileName: String = defaultModelFileName,
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        applicationSupportDirectory: URL? = applicationSupportModelsDirectory()
    ) throws -> URL {
        let fm = FileManager.default

        if let override = environment[environmentKey], !override.isEmpty {
            let url = URL(fileURLWithPath: override)
            guard fm.fileExists(atPath: url.path) else {
                throw GrammarEngineError.modelNotFound(override)
            }
            return url
        }

        if let url = applicationSupportDirectory?.appendingPathComponent(fileName),
           fm.fileExists(atPath: url.path) {
            return url
        }

        if let url = bundle.resourceURL?
            .appendingPathComponent(modelsDirectoryName)
            .appendingPathComponent(fileName),
            fm.fileExists(atPath: url.path) {
            return url
        }

        throw GrammarEngineError.modelNotFound(fileName)
    }
}
