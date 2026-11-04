import SwiftUI
import WidgetKit

private struct ShortcutEntry: TimelineEntry {
    let date: Date
}

private struct ShortcutProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShortcutEntry { ShortcutEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (ShortcutEntry) -> Void) {
        completion(ShortcutEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShortcutEntry>) -> Void) {
        completion(Timeline(entries: [ShortcutEntry(date: Date())], policy: .never))
    }
}

private struct ShortcutWidgetView: View {
    let title: String
    let subtitle: String
    let symbol: String
    let colors: [Color]
    let url: URL

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.13))
                .frame(width: 116, height: 116)
                .offset(x: 54, y: -52)

            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.white.opacity(0.19))
                    Image(systemName: symbol)
                        .font(.system(size: 27, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)

                Spacer(minLength: 12)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(16)
        }
        .modifier(WidgetGradientBackground(colors: colors))
        .widgetURL(url)
    }
}

/// GPT 快捷组件同款布局：顶部主入口，底部相机与语音两个独立入口。
/// 保留 Muse AI 原有蓝色渐变，并继续通过既有 Deep Link 打开对应功能页。
private struct AssistantShortcutWidgetView: View {
    private let shortcutDiameter: CGFloat = 62
    private let shortcutSpacing: CGFloat = 14
    private let chatURL = URL(string: "agentclaw://quick/chat")!
    private let imageURL = URL(string: "agentclaw://quick/image")!
    private let avatarURL = URL(string: "agentclaw://quick/avatar")!

    private let colors = [
        Color(red: 0.10, green: 0.48, blue: 0.95),
        Color(red: 0.18, green: 0.75, blue: 0.80)
    ]

    var body: some View {
        VStack(spacing: 10) {
            Link(destination: chatURL) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 21, weight: .regular))
                        .frame(width: 27)

                    Text("AI Agent")
                        .font(.system(size: 17, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)

                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(width: controlsWidth)
                .frame(height: 56)
                .background(shortcutBackground)
            }

            HStack(spacing: shortcutSpacing) {
                shortcutLink(symbol: "camera", label: "相机", destination: imageURL)
                shortcutLink(symbol: "waveform", label: "语音", destination: avatarURL)
            }
            .frame(width: controlsWidth)
        }
        .padding(8)
        .modifier(WidgetSystemMarginCompensation())
        .modifier(WidgetGradientBackground(colors: colors))
    }

    private var shortcutBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.18))
    }

    private var controlsWidth: CGFloat {
        shortcutDiameter * 2 + shortcutSpacing
    }

    private func shortcutLink(symbol: String, label: String, destination: URL) -> some View {
        Link(destination: destination) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: shortcutDiameter, height: shortcutDiameter)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.18))
                )
                .accessibilityLabel(label)
        }
    }
}

private struct WidgetSystemMarginCompensation: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            // WidgetKit 已在外层自动预留约 16pt；抵消它，仅保留上面的 8pt 自定义间距。
            content.padding(-16)
        } else {
            content
        }
    }
}

private struct WidgetGradientBackground: ViewModifier {
    let colors: [Color]

    private var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) {
                gradient
            }
        } else {
            content.background(gradient)
        }
    }
}

private struct ImageShortcutWidget: Widget {
    let kind = "AgentClawImageShortcut"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShortcutProvider()) { _ in
            ShortcutWidgetView(
                title: "一键生图",
                subtitle: "把灵感变成作品",
                symbol: "photo.on.rectangle.angled",
                colors: [Color(red: 0.43, green: 0.30, blue: 0.98), Color(red: 0.83, green: 0.34, blue: 0.78)],
                url: URL(string: "agentclaw://quick/image")!
            )
        }
        .configurationDisplayName("一键生图")
        .description("快速打开 AgentClaw AI 画图。")
        .supportedFamilies([.systemSmall])
    }
}

private struct AvatarShortcutWidget: Widget {
    let kind = "AgentClawAvatarShortcut"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShortcutProvider()) { _ in
            AssistantShortcutWidgetView()
        }
        .configurationDisplayName("Muse AI 快捷入口")
        .description("快速打开对话、相机生图和语音智能体。")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct AgentClawWidgetBundle: WidgetBundle {
    var body: some Widget {
        ImageShortcutWidget()
        AvatarShortcutWidget()
    }
}
