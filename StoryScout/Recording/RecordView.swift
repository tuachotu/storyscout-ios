import SwiftUI

struct RecordView: View {
    private struct UploadedRecording {
        let recording: Recording
        let fileURL: URL
    }

    let accessSession: AccessSession
    @StateObject private var recorder = RecordingController()
    @StateObject private var preview = AudioPreviewController()
    @State private var pendingUpload: RecordingUpload?
    @State private var uploadedRecording: UploadedRecording?
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var transcriptionText: String?
    @State private var isFetchingTranscription = false
    @State private var transcriptionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let uploadedRecording {
                completion(uploadedRecording)
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

    private func completion(_ uploaded: UploadedRecording) -> some View {
        ScrollView {
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
                Text(uploaded.recording.recordingId)
                    .font(.body.weight(.semibold))
                    .textSelection(.enabled)
                    .padding(.top, 4)

                Button(preview.isPlaying ? "Stop playback" : "Play recording") {
                    preview.toggle(url: uploaded.fileURL)
                }
                .buttonStyle(StoryButtonStyle())
                .disabled(isFetchingTranscription)
                .padding(.top, 24)

                Button(isFetchingTranscription ? "Fetching transcription…" : "Fetch transcription") {
                    Task { await fetchTranscription(recordingId: uploaded.recording.recordingId) }
                }
                .buttonStyle(StoryButtonStyle())
                .disabled(isFetchingTranscription)
                .padding(.top, 12)

                if isFetchingTranscription {
                    ProgressView()
                        .padding(.top, 16)
                        .accessibilityLabel("Fetching transcription")
                }

                if let transcriptionError {
                    Text(transcriptionError)
                        .foregroundColor(.storyError)
                        .padding(.top, 16)
                        .accessibilityLabel("Error: \(transcriptionError)")
                }

                if let transcriptionText {
                    Text("Transcription")
                        .font(.headline)
                        .padding(.top, 24)
                    Text(transcriptionText)
                        .foregroundColor(.storyPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }

                Button("Record another") {
                    preview.stop()
                    uploadedRecording = nil
                    pendingUpload = nil
                    uploadError = nil
                    transcriptionText = nil
                    transcriptionError = nil
                    recorder.recordAgain()
                }
                .buttonStyle(StoryButtonStyle())
                .disabled(isFetchingTranscription)
                .padding(.top, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            let recording = try await apiClient.completeRecording(
                recordingId: upload.recording.recordingId,
                accessToken: accessSession.accessToken
            )
            uploadedRecording = UploadedRecording(recording: recording, fileURL: fileURL)
        } catch {
            uploadError = error.localizedDescription
        }
    }

    private func fetchTranscription(recordingId: String) async {
        guard !isFetchingTranscription else { return }
        guard Date() < accessSession.expiresAt else {
            transcriptionError = "Your session has expired. Enter your access code again to fetch the transcription."
            return
        }

        isFetchingTranscription = true
        transcriptionError = nil
        preview.stop()
        defer { isFetchingTranscription = false }

        do {
            let response = try await APIClient.configured().fetchTranscription(
                recordingId: recordingId,
                accessToken: accessSession.accessToken
            )
            transcriptionText = response.transcription.text
        } catch {
            transcriptionError = error.localizedDescription
        }
    }
}
