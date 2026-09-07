import SwiftUI

struct SessionCountdownView: View {
    let expiresAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(for: SessionCountdown.state(expiresAt: expiresAt, now: context.date))
        }
    }

    @ViewBuilder
    private func content(for state: SessionCountdown) -> some View {
        switch state {
        case .hidden:
            EmptyView()
        case let .warning(message):
            Text(message)
                .font(.footnote.monospacedDigit())
                .foregroundColor(.storySecondaryText)
                .accessibilityLabel(message)
                .padding(.bottom, 12)
        case let .critical(message):
            Text(message)
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundColor(.storyError)
                .accessibilityLabel(message)
                .padding(.bottom, 12)
        case .expired:
            Text("Session expired. Enter your access code again before uploading.")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.storyError)
                .accessibilityLabel("Session expired. Enter your access code again before uploading.")
                .padding(.bottom, 12)
        }
    }
}
