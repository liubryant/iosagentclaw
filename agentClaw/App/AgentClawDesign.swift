import SwiftUI
import UIKit

enum AgentClawDesign {
    static let appBackground = Color(red: 0.94, green: 0.95, blue: 0.97)
    // 数字人舞台最顶部的底色。Duo 展开或铰链动画缩放内容时，
    // 外层会使用相同颜色承接，避免顶部安全区闪出白边。
    static let avatarStageTop = Color(red: 0.25, green: 0.15, blue: 0.48)
    static let sidebarBackground = Color(red: 0.89, green: 0.91, blue: 0.94)
    static let chatSurface = Color.white
    static let controlSurface = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let primaryText = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let secondaryText = Color(red: 0.38, green: 0.40, blue: 0.44)
    static let accent = Color(red: 0.23, green: 0.47, blue: 0.95)
    static let divider = Color.black.opacity(0.06)

    static func roundedCard(radius: CGFloat = 8) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(chatSurface)
    }
}

// MARK: - Rounded corners on specific edges (iOS 13 compatible)

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

