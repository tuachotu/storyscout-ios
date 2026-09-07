import SwiftUI

struct AccessView: View {
    @ObservedObject var model: AppModel
    @State private var accessCode = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Step 1 of 2")
                .font(.footnote)
                .foregroundColor(.storySecondaryText)

            Text("Enter your access code")
                .font(.system(size: 44, weight: .bold))
                .minimumScaleFactor(0.75)
                .padding(.top, 8)
                .padding(.bottom, 32)

            Text("Access code")
                .font(.body.weight(.semibold))
                .padding(.bottom, 8)

            TextField(
                "",
                text: $accessCode,
                prompt: Text("00000000-0000-0000-0000-000000000000")
                    .foregroundColor(.storySecondaryText)
            )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.asciiCapable)
                .textContentType(.oneTimeCode)
                .foregroundColor(.storyPrimary)
                .tint(.storyPrimary)
                .padding(14)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 183 / 255, green: 183 / 255, blue: 183 / 255))
                )
                .accessibilityLabel("Access code")
                .onChange(of: accessCode) { _ in model.accessError = nil }

            if let accessError = model.accessError {
                Text(accessError)
                    .foregroundColor(.storyError)
                    .padding(.top, 12)
                    .accessibilityLabel("Error: \(accessError)")
            }

            Button {
                Task { await model.continueWithAccessCode(accessCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
            } label: {
                Text(model.isCheckingAccess ? "Checking…" : "Continue")
            }
            .buttonStyle(StoryButtonStyle())
            .disabled(model.isCheckingAccess || accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.top, 12)
        }
    }
}
