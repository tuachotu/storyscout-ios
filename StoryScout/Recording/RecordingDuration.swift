import Foundation

enum RecordingDuration {
    static func format(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
