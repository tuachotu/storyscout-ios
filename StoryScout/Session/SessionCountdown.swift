import Foundation

enum SessionCountdown: Equatable {
    case hidden
    case warning(String)
    case critical(String)
    case expired

    static let warningThreshold: TimeInterval = 30 * 60
    static let criticalThreshold: TimeInterval = 5 * 60

    static func state(expiresAt: Date, now: Date) -> SessionCountdown {
        let remaining = expiresAt.timeIntervalSince(now)
        guard remaining > 0 else { return .expired }
        guard remaining <= warningThreshold else { return .hidden }

        let totalSeconds = Int(ceil(remaining))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let message = String(format: "Session expires in %02d:%02d", minutes, seconds)
        return remaining <= criticalThreshold ? .critical(message) : .warning(message)
    }
}
