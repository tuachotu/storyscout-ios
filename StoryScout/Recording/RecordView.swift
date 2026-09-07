import SwiftUI

struct RecordView: View {
    let accessSession: AccessSession
    @StateObject private var recorder = RecordingController()
    @StateObject private var preview = AudioPreviewController()
    @State private var pendingUpload: RecordingUpload?
    @State private var savedRecording: Recording?
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let savedRecording {
                completion(savedRecording)
            } else {
                recordingContent
            }
        }
    }

    private var recordingContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SessionCountdownView(expiresAt: accessSession.expiresAt)

            Text("Step 2 of 2")
                .font(.footnote)
                .foregroundColor(.storySecondaryText)

            Text("Record your story")
                .font(.system(size: 44, weight: .bold))
                .minimumScaleFactor(0.75)
                .padding(.top, 8)

            Text("Hi \(accessSession.displayName).")
                .font(.title3)
                .padding(.top, 12)

            Text(RecordingDuration.format(recorder.elapsed))
                .font(.system(size: 64, weight: .regular, design: .monospaced))
                .minimumScaleFactor(0.65)
                .accessibilityLabel("Recording time \(RecordingDuration.format(recorder.elapsed))")
                .padding(.top, 48)
                .padding(.bottom, 24)

            controls

            if isUploading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Uploading…")
                }
                .foregroundColor(.storySecondaryText)
                .padding(.top, 20)
                .accessibilityElement(children: .combine)
            }

            if let errorMessage = uploadError ?? preview.errorMessage ?? recorder.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.storyError)
                    .padding(.top, 20)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch recorder.state {
        case .idle:
            Button(recorder.isRequestingPermission ? "Requesting microphone…" : "Start recording") {
                recorder.start()
            }
            .buttonStyle(StoryButtonStyle())
            .disabled(recorder.isRequestingPermission)

        case .recording, .paused:
            HStack(spacing: 12) {
                Button(recorder.state == .paused ? "Resume" : "Pause") {
                    recorder.pauseOrResume()
                }
                .buttonStyle(StoryButtonStyle())

                Button("Stop") { recorder.stop() }
                    .buttonStyle(StoryButtonStyle())
            }

        case let .review(fileURL):
            VStack(alignment: .leading, spacing: 16) {
                Text("Recording ready")
                    .font(.headline)
                Text("Your recording is safely stored on this device.")
                    .foregroundColor(.storySecondaryText)

                Button(preview.isPlaying ? "Stop playback" : "Play recording") {
                    preview.toggle(url: fileURL)
                }
                .buttonStyle(StoryButtonStyle())
                .disabled(isUploading)

                HStack(spacing: 12) {
                    Button("Record again") {
                        preview.stop()
                        pendingUpload = nil
                        uploadError = nil
                        recorder.recordAgain()
                    }
                    .buttonStyle(StoryButtonStyle())
                    .disabled(isUploading)

                    Button("Upload") {
                        Task { await upload(fileURL: fileURL) }
                    }
                    .buttonStyle(StoryButtonStyle())
                    .disabled(isUploading)
                }
            }
        }
    }

    private func completion(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Complete")
                .font(.footnote)
                .foregroundColor(.storySecondaryText)
            Text("Recording saved")
                .font(.system(size: 44, weight: .bold))
                .minimumScaleFactor(0.75)
                .padding(.top, 8)
            Text("Your recording ID is")
                .padding(.top, 20)
            Text(recording.recordingId)
                .font(.body.weight(.semibold))
                .textSelection(.enabled)
                .padding(.top, 4)
            Button("Record another") {
                preview.stop()
                savedRecording = nil
                pendingUpload = nil
                uploadError = nil
                recorder.recordAgain()
            }
            .buttonStyle(StoryButtonStyle())
            .padding(.top, 24)
        }
    }

    private func upload(fileURL: URL) async {
        guard !isUploading else { return }
        guard Date() < accessSession.expiresAt else {
            uploadError = "Your session has expired. Your recording remains safely stored on this device."
            return
        }

        isUploading = true
        uploadError = nil
        preview.stop()
        defer { isUploading = false }

        do {
            let apiClient = try APIClient.configured()
            let upload: RecordingUpload
            if let pendingUpload {
                upload = pendingUpload
            } else {
                upload = try await apiClient.createRecording(
                    accessToken: accessSession.accessToken,
                    fileURL: fileURL
                )
                pendingUpload = upload
            }
            try await apiClient.uploadDirect(upload.upload, fileURL: fileURL)
            savedRecording = try await apiClient.completeRecording(
                recordingId: upload.recording.recordingId,
                accessToken: accessSession.accessToken
            )
        } catch {
            uploadError = error.localizedDescription
        }
    }
}
