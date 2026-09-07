import AVFoundation
import Foundation

@MainActor
final class RecordingController: NSObject, ObservableObject, AVAudioRecorderDelegate {
    enum State: Equatable {
        case idle
        case recording
        case paused
        case review(URL)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isRequestingPermission = false
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var interruptionObserver: NSObjectProtocol?

    override init() {
        super.init()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.handleInterruption(notification) }
        }
    }

    deinit {
        timer?.invalidate()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    func start() {
        guard state == .idle, !isRequestingPermission else { return }
        errorMessage = nil
        isRequestingPermission = true

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                self.isRequestingPermission = false
                guard granted else {
                    self.errorMessage = "Microphone permission was denied. Enable it in Settings to record your story."
                    return
                }
                self.beginRecording()
            }
        }
    }

    func pauseOrResume() {
        switch state {
        case .recording:
            recorder?.pause()
            updateElapsed()
            stopTimer()
            state = .paused
        case .paused:
            guard recorder?.record() == true else {
                errorMessage = "Recording could not resume."
                return
            }
            state = .recording
            startTimer()
        case .idle, .review:
            break
        }
    }

    func stop() {
        guard state == .recording || state == .paused, let recorder else { return }
        updateElapsed()
        stopTimer()
        recorder.stop()
        let url = recorder.url
        self.recorder = nil
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        state = .review(url)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func recordAgain() {
        guard case let .review(url) = state else { return }
        try? FileManager.default.removeItem(at: url)
        elapsed = 0
        errorMessage = nil
        state = .idle
    }

    private func beginRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)

            let directory = try recordingsDirectory()
            let url = directory.appendingPathComponent("story-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 96_000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record() else {
                throw RecordingError.couldNotStart
            }
            self.recorder = recorder
            elapsed = 0
            state = .recording
            startTimer()
        } catch {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            errorMessage = "Recording could not start. \(error.localizedDescription)"
        }
    }

    private func recordingsDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("PendingRecordings", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        return directory
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateElapsed() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsed() {
        elapsed = recorder?.currentTime ?? elapsed
    }

    private func handleInterruption(_ notification: Notification) {
        guard
            let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawValue)
        else { return }

        if type == .began, state == .recording {
            recorder?.pause()
            updateElapsed()
            stopTimer()
            state = .paused
            errorMessage = "Recording was paused by an audio interruption. Tap Resume when you are ready."
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(
        _ recorder: AVAudioRecorder,
        error: Error?
    ) {
        Task { @MainActor in
            stopTimer()
            updateElapsed()
            self.recorder = nil
            state = .review(recorder.url)
            errorMessage = error.map { "Recording encountered an error: \($0.localizedDescription)" }
                ?? "Recording encountered an unexpected error."
        }
    }
}

private enum RecordingError: LocalizedError {
    case couldNotStart

    var errorDescription: String? { "The microphone did not start recording." }
}
