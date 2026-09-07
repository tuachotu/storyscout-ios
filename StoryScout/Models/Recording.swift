import Foundation

struct Recording: Codable, Equatable {
    enum StorageState: String, Codable {
        case awaitingUpload
        case ready
    }

    let recordingId: String
    let participantName: String
    let createdAt: Date
    let completedAt: Date?
    let storageState: StorageState
    let originalFilename: String
    let contentType: String
    let sizeBytes: Int?
}

struct RecordingUpload: Codable, Equatable {
    struct Instructions: Codable, Equatable {
        let url: URL
        let method: String
        let headers: [String: String]
        let expiresAt: Date
    }

    let recording: Recording
    let upload: Instructions
}
