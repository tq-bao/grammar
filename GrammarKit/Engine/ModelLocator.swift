import Foundation

/// Tìm file model GGUF đóng gói trong app bundle.
public enum ModelLocator {
    /// Model mặc định, chọn theo kết quả GrammarBench (xem docs/model-benchmark.md).
    public static let defaultModelFileName = "Qwen2.5-7B-Instruct-Q4_K_M.gguf"

    /// Thư mục chứa model trong bundle (`Contents/Resources/Models`).
    public static let modelsDirectoryName = "Models"

    /// Biến môi trường để chỉ định đường dẫn model khi dev/benchmark.
    public static let environmentKey = "GRAMMAR_MODEL_PATH"

    public static func locate(
        fileName: String = defaultModelFileName,
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        let fm = FileManager.default

        if let override = environment[environmentKey], !override.isEmpty {
            let url = URL(fileURLWithPath: override)
            guard fm.fileExists(atPath: url.path) else {
                throw GrammarEngineError.modelNotFound(override)
            }
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
