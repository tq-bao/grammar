import Foundation

/// Bộ sửa ngữ pháp. Trả về câu đã sửa, hoặc trả nguyên văn nếu câu đã đúng.
public protocol GrammarEngine: Sendable {
    func correct(_ sentence: String) async throws -> String
}

public enum GrammarEngineError: LocalizedError, Equatable {
    case modelNotFound(String)
    case modelLoadFailed(String)
    case contextCreationFailed
    case promptTemplateFailed
    case tokenizeFailed
    case decodeFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case let .modelNotFound(name):
            "Không tìm thấy model \(name). Chạy scripts/download-model.sh rồi build lại app."
        case let .modelLoadFailed(path):
            "Không nạp được model tại \(path). File có thể bị hỏng, hãy tải lại."
        case .contextCreationFailed:
            "Không tạo được ngữ cảnh cho model (có thể thiếu bộ nhớ)."
        case .promptTemplateFailed:
            "Model không có chat template phù hợp."
        case .tokenizeFailed:
            "Không tách được token cho câu này."
        case let .decodeFailed(code):
            "Model gặp lỗi khi sinh kết quả (mã \(code))."
        }
    }
}
