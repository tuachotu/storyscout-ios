import AVFoundation
import Foundation

@MainActor
final class AudioPreviewController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?

    func toggle(url: URL) {
        if isPlaying {
            stop()
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            guard player.play() else { throw PreviewError.couldNotPlay }
            self.player = player
            isPlaying = true
            errorMessage = nil
        } catch {
            errorMessage = "The recording could not be played. \(error.localizedDescription)"
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            isPlaying = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            if !flag { errorMessage = "The recording stopped before playback completed." }
        }
    }
}

private enum PreviewError: LocalizedError {
    case couldNotPlay

    var errorDescription: String? { "Audio playback did not start." }
}
