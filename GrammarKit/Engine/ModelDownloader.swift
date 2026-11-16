import CryptoKit
import Foundation

/// Sự kiện trong lúc tải model.
public enum ModelDownloadEvent: Equatable, Sendable {
    /// Đã có `received` trên tổng `total` byte (tính cả phần tải từ lần trước).
    case progress(received: Int64, total: Int64)
    /// Đã tải đủ, đang kiểm tra định dạng và checksum.
    case verifying
}

public enum ModelDownloadError: LocalizedError, Equatable {
    case insufficientDiskSpace(required: Int64)
    case http(Int)
    case network(String)
    case sizeMismatch(expected: Int64, actual: Int64)
    case notGGUF
    case checksumMismatch
    case fileSystem(String)

    public var errorDescription: String? {
        switch self {
        case let .insufficientDiskSpace(required):
            "Không đủ dung lượng để tải model. Cần trống thêm khoảng \(Self.gigabytes(required)) trên ổ đĩa."
        case let .http(status):
            "Không tải được model: máy chủ trả mã \(status)."
        case let .network(message):
            "Không tải được model: \(message)"
        case .sizeMismatch:
            "File model tải về không đầy đủ. Hãy tải lại."
        case .notGGUF:
            "File tải về không phải model GGUF. Hãy tải lại."
        case .checksumMismatch:
            "File model tải về bị hỏng (sai checksum). Hãy tải lại."
        case let .fileSystem(message):
            "Không ghi được file model: \(message)"
        }
    }

    /// "1.5 GB" (GB thập phân, như Finder).
    private static func gigabytes(_ bytes: Int64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
    }
}

/// Tải model về `destination`: ghi vào `<destination>.part`, tải tiếp bằng header `Range`,
/// kiểm tra định dạng GGUF và SHA256 rồi mới đổi tên thành file thật.
/// Huỷ (cancel Task) giữ lại `.part` để lần sau tải tiếp.
public actor ModelDownloader {
    public typealias CapacityProvider = @Sendable (URL) -> Int64?

    public nonisolated let url: URL
    public nonisolated let destination: URL
    public nonisolated let expectedSize: Int64
    public nonisolated let sha256: String
    private let configuration: URLSessionConfiguration
    private let reserveBytes: Int64
    private let availableCapacity: CapacityProvider

    public init(
        url: URL = ModelLocator.defaultModelURL,
        destination: URL,
        expectedSize: Int64 = ModelLocator.defaultModelSize,
        sha256: String = ModelLocator.defaultModelSHA256,
        configuration: URLSessionConfiguration = .default,
        reserveBytes: Int64 = 512 * 1_000_000,
        availableCapacity: @escaping CapacityProvider = ModelDownloader.systemAvailableCapacity
    ) {
        self.url = url
        self.destination = destination
        self.expectedSize = expectedSize
        self.sha256 = sha256.lowercased()
        self.configuration = configuration
        self.reserveBytes = reserveBytes
        self.availableCapacity = availableCapacity
    }

    /// File tạm đang tải dở.
    public nonisolated var partialURL: URL {
        Self.partialURL(for: destination)
    }

    public static func partialURL(for destination: URL) -> URL {
        destination.deletingLastPathComponent().appendingPathComponent(destination.lastPathComponent + ".part")
    }

    /// Số byte đã tải ở lần trước (0 nếu chưa có `.part`).
    public static func partialBytes(for destination: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: partialURL(for: destination).path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// Dung lượng trống của ổ chứa `url` (dùng khoá "important usage" như Finder).
    public static let systemAvailableCapacity: CapacityProvider = { url in
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    /// Tải, kiểm tra và trả về đường dẫn file model.
    @discardableResult
    public func download(onEvent: @escaping @Sendable (ModelDownloadEvent) -> Void = { _ in }) async throws -> URL {
        let fm = FileManager.default
        let directory = destination.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw ModelDownloadError.fileSystem(error.localizedDescription)
        }

        var offset = Self.partialBytes(for: destination)
        if offset > expectedSize {
            try? fm.removeItem(at: partialURL)
            offset = 0
        }

        if offset < expectedSize {
            let remaining = expectedSize - offset
            if let free = availableCapacity(directory), free < remaining + reserveBytes {
                throw ModelDownloadError.insufficientDiskSpace(required: remaining + reserveBytes - free)
            }
            onEvent(.progress(received: offset, total: expectedSize))
            try await fetch(from: offset, onEvent: onEvent)
        }

        onEvent(.verifying)
        try verifyAndInstall()
        return destination
    }

    // MARK: - Tải

    private func fetch(from offset: Int64, onEvent: @escaping @Sendable (ModelDownloadEvent) -> Void) async throws {
        try Task.checkCancellation()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if offset > 0 {
            request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range")
        }

        let delegate = PartialFileWriter(partialURL: partialURL, offset: offset, total: expectedSize, onEvent: onEvent)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let task = session.dataTask(with: request)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                delegate.start(task, continuation: continuation)
            }
        } onCancel: {
            task.cancel()
        }
    }

    // MARK: - Kiểm tra

    private func verifyAndInstall() throws {
        let fm = FileManager.default
        let part = partialURL

        func reject(_ error: ModelDownloadError) -> ModelDownloadError {
            try? fm.removeItem(at: part)
            return error
        }

        let actual = Self.partialBytes(for: destination)
        guard actual == expectedSize else {
            throw reject(.sizeMismatch(expected: expectedSize, actual: actual))
        }

        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: part)
        } catch {
            throw ModelDownloadError.fileSystem(error.localizedDescription)
        }
        defer { try? handle.close() }

        var hasher = SHA256()
        var isFirstChunk = true
        while true {
            let chunk: Data
            do {
                chunk = try handle.read(upToCount: 8 * 1024 * 1024) ?? Data()
            } catch {
                throw ModelDownloadError.fileSystem(error.localizedDescription)
            }
            if chunk.isEmpty { break }
            if isFirstChunk {
                guard chunk.prefix(4) == Data("GGUF".utf8) else { throw reject(.notGGUF) }
                isFirstChunk = false
            }
            hasher.update(data: chunk)
        }

        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == sha256 else { throw reject(.checksumMismatch) }

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: part, to: destination)
        } catch {
            throw ModelDownloadError.fileSystem(error.localizedDescription)
        }
    }
}

/// Nhận dữ liệu từ `URLSession` và ghi thẳng vào file `.part`, theo từng khối.
/// Các callback của delegate chạy tuần tự trên hàng đợi riêng của session.
private final class PartialFileWriter: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let partialURL: URL
    private let offset: Int64
    private let total: Int64
    private let onEvent: @Sendable (ModelDownloadEvent) -> Void

    private var handle: FileHandle?
    private var received: Int64 = 0
    private var lastReport = Date.distantPast
    private var failure: Error?
    private var continuation: CheckedContinuation<Void, Error>?

    init(partialURL: URL, offset: Int64, total: Int64, onEvent: @escaping @Sendable (ModelDownloadEvent) -> Void) {
        self.partialURL = partialURL
        self.offset = offset
        self.total = total
        self.onEvent = onEvent
    }

    func start(_ task: URLSessionDataTask, continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
        task.resume()
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        do {
            switch status {
            case 206 where offset > 0:
                // Server tải tiếp từ `offset`: ghi nối vào cuối file.
                handle = try FileHandle(forWritingTo: partialURL)
                try handle?.seekToEnd()
                received = offset
            case 200, 206:
                // Server gửi lại từ đầu (không hỗ trợ Range, hoặc chưa có `.part`).
                FileManager.default.createFile(atPath: partialURL.path, contents: nil)
                handle = try FileHandle(forWritingTo: partialURL)
                try handle?.truncate(atOffset: 0)
                received = 0
            default:
                failure = ModelDownloadError.http(status)
                completionHandler(.cancel)
                return
            }
        } catch {
            failure = ModelDownloadError.fileSystem(error.localizedDescription)
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let handle, failure == nil else { return }
        do {
            try handle.write(contentsOf: data)
        } catch {
            failure = ModelDownloadError.fileSystem(error.localizedDescription)
            dataTask.cancel()
            return
        }
        received += Int64(data.count)
        let now = Date()
        if now.timeIntervalSince(lastReport) >= 0.1 {
            lastReport = now
            onEvent(.progress(received: received, total: total))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        try? handle?.synchronize()
        try? handle?.close()
        handle = nil

        let result: Result<Void, Error>
        if let failure {
            result = .failure(failure)
        } else if let error {
            if (error as? URLError)?.code == .cancelled {
                result = .failure(CancellationError())
            } else {
                result = .failure(ModelDownloadError.network(error.localizedDescription))
            }
        } else {
            onEvent(.progress(received: received, total: total))
            result = .success(())
        }
        continuation?.resume(with: result)
        continuation = nil
    }
}
