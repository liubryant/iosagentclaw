import SwiftUI

enum AgentClawDesign {
    static let appBackground = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let sidebarBackground = Color(red: 0.89, green: 0.91, blue: 0.94)
    static let chatSurface = Color.white
    static let controlSurface = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let primaryText = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let secondaryText = Color(red: 0.45, green: 0.47, blue: 0.52)
    static let accent = Color(red: 0.23, green: 0.47, blue: 0.95)
    static let divider = Color.black.opacity(0.06)

    static func roundedCard(radius: CGFloat = 8) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(chatSurface)
    }
}

