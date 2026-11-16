import CryptoKit
import XCTest
@testable import GrammarKit

/// Máy chủ giả cho `ModelDownloader`: phục vụ một file nhỏ, hỗ trợ (hoặc bỏ qua) header `Range`,
/// và ghi lại mọi request nhận được.
final class MockModelServer: @unchecked Sendable {
    static let shared = MockModelServer()

    private let lock = NSLock()
    private var _payload = Data()
    private var _forcedStatus: Int?
    private var _honorRange = true
    private var _slow = false
    private var _requests: [URLRequest] = []

    func reset(payload: Data) {
        lock.withLock {
            _payload = payload
            _forcedStatus = nil
            _honorRange = true
            _slow = false
            _requests = []
        }
    }

    var payload: Data { lock.withLock { _payload } }
    var forcedStatus: Int? {
        get { lock.withLock { _forcedStatus } }
        set { lock.withLock { _forcedStatus = newValue } }
    }
    var honorRange: Bool {
        get { lock.withLock { _honorRange } }
        set { lock.withLock { _honorRange = newValue } }
    }
    /// Gửi khối đầu rồi dừng lâu, để test huỷ giữa chừng.
    var slow: Bool {
        get { lock.withLock { _slow } }
        set { lock.withLock { _slow = newValue } }
    }
    var requests: [URLRequest] { lock.withLock { _requests } }
    func record(_ request: URLRequest) { lock.withLock { _requests.append(request) } }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    private let stateLock = NSLock()
    private var stopped = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let server = MockModelServer.shared
        server.record(request)
        let url = request.url!

        if let status = server.forcedStatus {
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: [:])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let payload = server.payload
        var start = 0
        var status = 200
        if server.honorRange,
           let range = request.value(forHTTPHeaderField: "Range"),
           range.hasPrefix("bytes="), range.hasSuffix("-"),
           let value = Int(range.dropFirst("bytes=".count).dropLast()) {
            start = value
            status = 206
        }
        let body = payload.subdata(in: start..<payload.count)
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": "\(body.count)"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        let chunk = 8 * 1024
        if server.slow {
            client?.urlProtocol(self, didLoad: body.prefix(chunk))
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self, !self.isStopped else { return }
                self.client?.urlProtocol(self, didLoad: body.dropFirst(chunk))
                self.client?.urlProtocolDidFinishLoading(self)
            }
            return
        }

        var index = body.startIndex
        while index < body.endIndex {
            let end = min(index + chunk, body.endIndex)
            client?.urlProtocol(self, didLoad: body.subdata(in: index..<end))
            index = end
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        stateLock.withLock { stopped = true }
    }

    private var isStopped: Bool { stateLock.withLock { stopped } }
}

/// Ghi lại các sự kiện tiến độ (callback chạy trên luồng của URLSession).
final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [ModelDownloadEvent] = []
    var onEvent: (@Sendable (ModelDownloadEvent) -> Void)?

    func record(_ event: ModelDownloadEvent) {
        lock.withLock { _events.append(event) }
        onEvent?(event)
    }

    var events: [ModelDownloadEvent] { lock.withLock { _events } }
}

final class ModelDownloaderTests: XCTestCase {
    private var directory: URL!
    private var destination: URL!
    private var payload: Data!
    private var payloadSHA: String!
    private let url = URL(string: "https://models.example/m.gguf")!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("ModelDownloaderTests-\(UUID().uuidString)")
        destination = directory.appendingPathComponent("Models/m.gguf")
        var bytes = Data("GGUF".utf8)
        bytes.append(Data((0..<(64 * 1024 - 4)).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }))
        payload = bytes
        payloadSHA = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        MockModelServer.shared.reset(payload: bytes)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeDownloader(sha256: String? = nil, freeSpace: Int64? = nil) -> ModelDownloader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return ModelDownloader(
            url: url,
            destination: destination,
            expectedSize: Int64(payload.count),
            sha256: sha256 ?? payloadSHA,
            configuration: configuration,
            reserveBytes: 1024,
            availableCapacity: { _ in freeSpace }
        )
    }

    private var partURL: URL { ModelDownloader.partialURL(for: destination) }

    private func writePart(_ data: Data) throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: partURL)
    }

    // Scenario: File hợp lệ
    func testFullDownloadInstallsVerifiedFile() async throws {
        let recorder = EventRecorder()
        let result = try await makeDownloader().download { recorder.record($0) }

        XCTAssertEqual(result, destination)
        XCTAssertEqual(try Data(contentsOf: destination), payload)
        XCTAssertFalse(FileManager.default.fileExists(atPath: partURL.path))
        XCTAssertEqual(recorder.events.last, .verifying)
        XCTAssertTrue(recorder.events.contains(.progress(received: Int64(payload.count), total: Int64(payload.count))))
        XCTAssertNil(MockModelServer.shared.requests.first?.value(forHTTPHeaderField: "Range"))
    }

    // Scenario: Mất mạng giữa chừng → tải tiếp từ phần đã có
    func testResumesFromPartialFileWithRangeHeader() async throws {
        try writePart(payload.prefix(10_000))

        try await makeDownloader().download()

        XCTAssertEqual(MockModelServer.shared.requests.count, 1)
        XCTAssertEqual(MockModelServer.shared.requests.first?.value(forHTTPHeaderField: "Range"), "bytes=10000-")
        XCTAssertEqual(try Data(contentsOf: destination), payload)
    }

    func testRestartsWhenServerIgnoresRange() async throws {
        try writePart(Data(repeating: 0xAB, count: 10_000))
        MockModelServer.shared.honorRange = false

        try await makeDownloader().download()

        XCTAssertEqual(try Data(contentsOf: destination), payload)
    }

    func testCompletePartialFileIsVerifiedWithoutNetwork() async throws {
        try writePart(payload)

        try await makeDownloader().download()

        XCTAssertTrue(MockModelServer.shared.requests.isEmpty)
        XCTAssertEqual(try Data(contentsOf: destination), payload)
    }

    // Scenario: File tải về bị hỏng
    func testChecksumMismatchDeletesPartialFile() async throws {
        do {
            try await makeDownloader(sha256: String(repeating: "0", count: 64)).download()
            XCTFail("Phải báo sai checksum")
        } catch {
            XCTAssertEqual(error as? ModelDownloadError, .checksumMismatch)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: partURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testNonGGUFFileIsRejected() async throws {
        var bad = payload!
        bad.replaceSubrange(0..<4, with: Data("HTML".utf8))
        MockModelServer.shared.reset(payload: bad)
        let badSHA = SHA256.hash(data: bad).map { String(format: "%02x", $0) }.joined()

        do {
            try await makeDownloader(sha256: badSHA).download()
            XCTFail("Phải báo không phải GGUF")
        } catch {
            XCTAssertEqual(error as? ModelDownloadError, .notGGUF)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    // Requirement: Lỗi khi tải
    func testHTTPErrorIsReported() async throws {
        MockModelServer.shared.forcedStatus = 404
        do {
            try await makeDownloader().download()
            XCTFail("Phải báo lỗi HTTP")
        } catch {
            XCTAssertEqual(error as? ModelDownloadError, .http(404))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    // Scenario: Ổ đĩa gần đầy
    func testInsufficientDiskSpaceSendsNoRequest() async throws {
        do {
            try await makeDownloader(freeSpace: 1000).download()
            XCTFail("Phải báo thiếu dung lượng")
        } catch let ModelDownloadError.insufficientDiskSpace(required) {
            XCTAssertEqual(required, Int64(payload.count) + 1024 - 1000)
        }
        XCTAssertTrue(MockModelServer.shared.requests.isEmpty)
    }

    // Scenario: Huỷ tải → giữ phần đã tải
    func testCancelKeepsPartialFile() async throws {
        MockModelServer.shared.slow = true
        let downloader = makeDownloader()
        let gotData = expectation(description: "đã nhận dữ liệu")
        gotData.assertForOverFulfill = false
        let recorder = EventRecorder()
        recorder.onEvent = { event in
            if case let .progress(received, _) = event, received > 0 { gotData.fulfill() }
        }

        let task = Task { try await downloader.download { recorder.record($0) } }
        await fulfillment(of: [gotData], timeout: 5)
        task.cancel()

        do {
            try await task.value
            XCTFail("Phải bị huỷ")
        } catch {
            XCTAssertTrue(error is CancellationError, "\(error)")
        }
        XCTAssertGreaterThan(ModelDownloader.partialBytes(for: destination), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    // Requirement: Không gửi nội dung người dùng khi tải
    func testOnlyPlainGETToConfiguredURL() async throws {
        try await makeDownloader().download()

        let requests = MockModelServer.shared.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.httpMethod, "GET")
        XCTAssertEqual(requests.first?.url, url)
        XCTAssertNil(requests.first?.httpBody)
        XCTAssertNil(requests.first?.httpBodyStream)
    }

    func testPartialBytesReportsZeroWithoutPartFile() {
        XCTAssertEqual(ModelDownloader.partialBytes(for: destination), 0)
    }
}
