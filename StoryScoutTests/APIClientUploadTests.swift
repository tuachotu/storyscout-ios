import XCTest
@testable import StoryScout

final class APIClientUploadTests: XCTestCase {
    private var session: URLSession!
    private var client: APIClient!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        client = APIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: session
        )
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        session.invalidateAndCancel()
        client = nil
        session = nil
        super.tearDown()
    }

    func testCreateRecordingSendsExpectedMetadataAndAuthorization() async throws {
        let fileURL = try temporaryAudioFile(bytes: Data(repeating: 7, count: 12))
        defer { try? FileManager.default.removeItem(at: fileURL) }

        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.test/api/v1/recordings")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try Self.requestBody(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["originalFilename"] as? String, fileURL.lastPathComponent)
            XCTAssertEqual(json["contentType"] as? String, "audio/mp4")
            XCTAssertEqual(json["sizeBytes"] as? Int, 12)
            return try Self.jsonResponse(for: request, body: Self.uploadResponseJSON)
        }

        let result = try await client.createRecording(accessToken: "token-123", fileURL: fileURL)
        XCTAssertEqual(result.recording.recordingId, "recording_123")
        XCTAssertEqual(result.upload.method, "PUT")
    }

    func testDirectUploadUsesPresignedMethodAndHeaders() async throws {
        let fileURL = try temporaryAudioFile(bytes: Data(repeating: 3, count: 8))
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let instructions = RecordingUpload.Instructions(
            url: URL(string: "https://uploads.example.test/object")!,
            method: "PUT",
            headers: ["Content-Type": "audio/mp4", "x-test": "signed-value"],
            expiresAt: Date().addingTimeInterval(900)
        )

        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url, instructions.url)
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "audio/mp4")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-test"), "signed-value")
            return (HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!, Data())
        }

        try await client.uploadDirect(instructions, fileURL: fileURL)
    }

    func testCompleteRecordingUsesRecordingSpecificEndpoint() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://example.test/api/v1/recordings/recording_123/complete"
            )
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
            return try Self.jsonResponse(for: request, body: Self.completedRecordingJSON)
        }

        let recording = try await client.completeRecording(
            recordingId: "recording_123",
            accessToken: "token-123"
        )
        XCTAssertEqual(recording.storageState, .ready)
    }

    private func temporaryAudioFile(bytes: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        try bytes.write(to: url)
        return url
    }

    private static func jsonResponse(for request: URLRequest, body: String) throws -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }

    private static func requestBody(from request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw try XCTUnwrap(stream.streamError) }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private static let uploadResponseJSON = """
    {
      "recording": {
        "recordingId": "recording_123",
        "participantName": "Puran",
        "createdAt": "2026-09-06T12:00:00.000Z",
        "completedAt": null,
        "storageState": "awaitingUpload",
        "originalFilename": "story.m4a",
        "contentType": "audio/mp4",
        "sizeBytes": 12
      },
      "upload": {
        "url": "https://uploads.example.test/object",
        "method": "PUT",
        "headers": { "Content-Type": "audio/mp4" },
        "expiresAt": "2026-09-06T12:15:00.000Z"
      }
    }
    """

    private static let completedRecordingJSON = """
    {
      "recordingId": "recording_123",
      "participantName": "Puran",
      "createdAt": "2026-09-06T12:00:00.000Z",
      "completedAt": "2026-09-06T12:01:00.000Z",
      "storageState": "ready",
      "originalFilename": "story.m4a",
      "contentType": "audio/mp4",
      "sizeBytes": 12
    }
    """
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
