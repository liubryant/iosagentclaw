import SwiftUI

struct ShellView: View {
    private enum Destination {
        case chat
        case ideas
    }

    @StateObject private var gatewayViewModel: GatewayConnectionViewModel
    @StateObject private var chatViewModel: ChatViewModel
    @State private var isSidebarVisible = true
    @State private var isSettingsPresented = false
    @State private var sidebarQuery = ""
    @State private var destination: Destination = .chat

    init(container: DependencyContainer) {
        _gatewayViewModel = StateObject(
            wrappedValue: GatewayConnectionViewModel(gatewayClient: container.gatewayClient)
        )
        _chatViewModel = StateObject(
            wrappedValue: ChatViewModel(
                gatewayClient: container.gatewayClient,
                preferences: container.preferences
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HStack(spacing: 0) {
                    if isSidebarVisible {
                        sidebar
                            .frame(width: sidebarWidth(for: proxy.size.width))
                            .transition(.move(edge: .leading))
                    }

                    mainPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(4)
                }
                .background(AgentClawDesign.appBackground.edgesIgnoringSafeArea(.all))

                if isSettingsPresented {
                    SettingsPanelView(
                        gatewayViewModel: gatewayViewModel,
                        isPresented: $isSettingsPresented
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 12) {
            searchField

            Button(action: {
                destination = .chat
                chatViewModel.createSession()
            }) {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("新对话")
                    Spacer()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AgentClawDesign.primaryText)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Color.white.opacity(0.72))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredSessions) { session in
                        sessionRow(session)
                    }
                }
                .padding(.top, 2)
            }

            VStack(spacing: 4) {
                sidebarNavItem(icon: "sparkles", title: "灵感泉涌", subtitle: "提示词模板") {
                    destination = .ideas
                }
                sidebarNavItem(icon: "folder", title: "文件", subtitle: "文件与导出") {}
                sidebarNavItem(icon: "gearshape", title: "设置", subtitle: "服务器、技能、关于") {
                    isSettingsPresented = true
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 16)
        .background(AgentClawDesign.sidebarBackground)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                .foregroundColor(AgentClawDesign.secondaryText)
            TextField("搜索历史", text: $sidebarQuery)
                .font(.system(size: 12))
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(Color.white.opacity(0.76))
        .cornerRadius(8)
    }

    private var mainPanel: some View {
        Group {
            switch destination {
            case .chat:
                chatPanel
            case .ideas:
                ideasPanel
            }
        }
    }

    private var chatPanel: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider().background(AgentClawDesign.divider)
            ChatView(viewModel: chatViewModel)
        }
        .background(AgentClawDesign.chatSurface)
        .cornerRadius(10)
    }

    private var ideasPanel: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider().background(AgentClawDesign.divider)
            FancyIdeasView { idea in
                destination = .chat
                chatViewModel.createSession(withDraft: idea.prompt)
            }
        }
        .background(AgentClawDesign.chatSurface)
        .cornerRadius(10)
    }

    private var chatHeader: some View {
        HStack(spacing: 8) {
            Button(action: { withAnimation { isSidebarVisible.toggle() } }) {
                Image(systemName: "sidebar.left")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(HeaderIconButtonStyle())

            Button(action: {
                destination = .chat
                chatViewModel.createSession()
            }) {
                Image(systemName: "plus.bubble")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(HeaderIconButtonStyle())

            Spacer()

            Button(action: { isSettingsPresented = true }) {
                Image(systemName: "gearshape")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(HeaderIconButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var filteredSessions: [LocalChatSession] {
        let query = sidebarQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return chatViewModel.sessions
        }
        return chatViewModel.sessions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func sessionRow(_ session: LocalChatSession) -> some View {
        let selected = session.id == chatViewModel.selectedSessionID

        return Button(action: {
            destination = .chat
            chatViewModel.selectSession(session)
        }) {
            HStack(spacing: 10) {
                Image(systemName: "message")
                    .font(.system(size: 11))
                    .foregroundColor(selected ? AgentClawDesign.accent : AgentClawDesign.secondaryText)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.system(size: 11, weight: selected ? .semibold : .regular))
                        .foregroundColor(AgentClawDesign.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(relativeDate(session.updatedAt))
                        .font(.system(size: 8))
                        .foregroundColor(AgentClawDesign.secondaryText)
                }

                Spacer()

                Button(action: { chatViewModel.deleteSession(session) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(AgentClawDesign.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background(selected ? Color.white : Color.white.opacity(0.42))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func sidebarNavItem(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 20)
                    .foregroundColor(AgentClawDesign.primaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AgentClawDesign.primaryText)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(AgentClawDesign.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(Color.white.opacity(0.44))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func sidebarWidth(for width: CGFloat) -> CGFloat {
        width * 2 / 5.5
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct HeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AgentClawDesign.primaryText)
            .background(configuration.isPressed ? Color.black.opacity(0.08) : AgentClawDesign.controlSurface)
            .cornerRadius(8)
    }
}
