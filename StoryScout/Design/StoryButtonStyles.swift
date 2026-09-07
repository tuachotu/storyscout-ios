import SwiftUI

struct StoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(.storyPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 20)
            .background(Color(red: 238 / 255, green: 238 / 255, blue: 238 / 255))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
