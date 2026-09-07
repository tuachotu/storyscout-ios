import SwiftUI

struct RootView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        ZStack {
            Color.storyBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("StoryScout")
                    .font(.headline.weight(.bold))
                    .tracking(-0.3)
                    .padding(.bottom, 48)

                if let accessSession = model.accessSession {
                    RecordView(accessSession: accessSession)
                } else {
                    AccessView(model: model)
                }

                Spacer()
            }
            .frame(maxWidth: 480, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .foregroundColor(.storyPrimary)
        }
        .preferredColorScheme(.light)
    }
}

extension Color {
    static let storyBackground = Color.white
    static let storyPrimary = Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
    static let storySecondaryText = Color(red: 104 / 255, green: 104 / 255, blue: 104 / 255)
    static let storyError = Color(red: 163 / 255, green: 25 / 255, blue: 25 / 255)
}
