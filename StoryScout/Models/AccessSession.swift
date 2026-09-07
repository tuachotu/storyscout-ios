import Foundation

struct AccessSession: Codable, Equatable {
    let accessToken: String
    let displayName: String
    let expiresAt: Date
}
