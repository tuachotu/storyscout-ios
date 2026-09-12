import Foundation

struct APIErrorResponse: Decodable {
    struct Details: Decodable {
        let code: String
        let message: String
        let requestId: String
    }

    let error: Details
}

enum APIClientError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case server(statusCode: Int, code: String, message: String, requestId: String?)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "StoryScout is not configured correctly."
        case .invalidResponse:
            return "StoryScout returned an invalid response."
        case let .server(_, _, message, _):
            return message
        }
    }
}

struct APIClient {
    let baseURL: URL
    var session: URLSession = .shared

    static func configured(bundle: Bundle = .main) throws -> APIClient {
        guard
            let value = bundle.object(forInfoDictionaryKey: "STORYSCOUT_API_BASE_URL") as? String,
            let rejectLoopbackValue = bundle.object(forInfoDictionaryKey: "STORYSCOUT_REJECT_LOOPBACK") as? String
        else {
            throw APIClientError.invalidConfiguration
        }
        return APIClient(
            baseURL: try normalizedBaseURL(
                from: value,
                rejectLoopback: rejectLoopbackValue.caseInsensitiveCompare("YES") == .orderedSame
            )
        )
    }

    static func normalizedBaseURL(from value: String, rejectLoopback: Bool) throws -> URL {
        let normalized = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard
            let url = URL(string: normalized),
            let scheme = url.scheme?.lowercased(),
            let host = url.host?.lowercased(),
            !scheme.isEmpty,
            !host.isEmpty
        else {
            throw APIClientError.invalidConfiguration
        }
        if rejectLoopback && (host == "127.0.0.1" || host == "localhost" || host == "::1") {
            throw APIClientError.invalidConfiguration
        }
        return url
    }

    func createAccessSession(guid: String) async throws -> AccessSession {
        struct Body: Encodable { let guid: String }

        var request = URLRequest(url: baseURL.appendingPathComponent("access-sessions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Body(guid: guid))
        return try await send(request)
    }

    func createRecording(accessToken: String, fileURL: URL) async throws -> RecordingUpload {
        struct Body: Encodable {
            let originalFilename: String
            let contentType: String
            let sizeBytes: Int
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let fileSize = attributes[.size] as? NSNumber, fileSize.intValue > 0 else {
            throw APIClientError.invalidResponse
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("recordings"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            Body(
                originalFilename: fileURL.lastPathComponent,
                contentType: "audio/mp4",
                sizeBytes: fileSize.intValue
            )
        )
        return try await send(request)
    }

    func uploadDirect(_ instructions: RecordingUpload.Instructions, fileURL: URL) async throws {
        var request = URLRequest(url: instructions.url)
        request.httpMethod = instructions.method
        for (name, value) in instructions.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        let (_, response) = try await session.upload(for: request, fromFile: fileURL)
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIClientError.server(
                statusCode: status,
                code: "UPLOAD_FAILED",
                message: "The recording upload failed.",
                requestId: nil
            )
        }
    }

    func completeRecording(recordingId: String, accessToken: String) async throws -> Recording {
        var request = URLRequest(
            url: baseURL
                .appendingPathComponent("recordings")
                .appendingPathComponent(recordingId)
                .appendingPathComponent("complete")
        )
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await send(request)
    }

    func fetchTranscription(
        recordingId: String,
        accessToken: String
    ) async throws -> RecordingTranscription {
        var request = URLRequest(
            url: baseURL
                .appendingPathComponent("recordings")
                .appendingPathComponent(recordingId)
                .appendingPathComponent("transcription")
        )
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await send(request)
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let details = try? decoder.decode(APIErrorResponse.self, from: data).error
            throw APIClientError.server(
                statusCode: httpResponse.statusCode,
                code: details?.code ?? "REQUEST_FAILED",
                message: details?.message ?? "Request failed with status \(httpResponse.statusCode).",
                requestId: details?.requestId
            )
        }
        return try decoder.decode(Response.self, from: data)
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO-8601 timestamp."
            )
        }
        return decoder
    }
}
