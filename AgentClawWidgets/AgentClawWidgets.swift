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
            ShortcutWidgetView(
                title: "AI 智能体",
                subtitle: "随时开始面对面对话",
                symbol: "person.crop.circle.badge.waveform",
                colors: [Color(red: 0.10, green: 0.48, blue: 0.95), Color(red: 0.18, green: 0.75, blue: 0.80)],
                url: URL(string: "agentclaw://quick/avatar")!
            )
        }
        .configurationDisplayName("AI 智能体")
        .description("快速打开 AgentClaw 数字人。")
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
