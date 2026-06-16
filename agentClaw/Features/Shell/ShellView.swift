import SwiftUI

struct ShellView: View {
    private enum Destination {
        case chat
        case ideas
    }

    @ObservedObject private var gatewayViewModel: GatewayConnectionViewModel
    @ObservedObject private var chatViewModel: ChatViewModel
    @State private var isSidebarVisible = true
    @State private var isSettingsPresented = false
    @State private var isDocumentsPresented = false
    @State private var sidebarQuery = ""
    @State private var destination: Destination = .chat
    @State private var sessionToDelete: LocalChatSession?
    @State private var showDeleteAlert = false

    init(container: DependencyContainer) {
        self.gatewayViewModel = GatewayConnectionViewModel(gatewayClient: container.gatewayClient)
        self.chatViewModel = ChatViewModel(
            gatewayClient: container.gatewayClient,
            preferences: container.preferences,
            generatedDocumentStore: container.generatedDocumentStore
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
                        chatViewModel: chatViewModel,
                        isPresented: $isSettingsPresented
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }

                if isDocumentsPresented {
                    DocumentsListView(
                        chatViewModel: chatViewModel,
                        isPresented: $isDocumentsPresented
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
                VStack(spacing: 6) {
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
                sidebarNavItem(icon: "folder", title: "文件", subtitle: "文件与分享") {
                    isDocumentsPresented = true
                }
                sidebarNavItem(icon: "slide_setting", title: "设置", subtitle: "技能和关于", isCustomIcon: true) {
                    isSettingsPresented = true
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 16)
        .background(AgentClawDesign.sidebarBackground)
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("删除对话"),
                message: Text("确定要删除这个对话吗？此操作无法撤销。"),
                primaryButton: .destructive(Text("删除")) {
                    if let session = sessionToDelete {
                        chatViewModel.deleteSession(session)
                        sessionToDelete = nil
                    }
                },
                secondaryButton: .cancel(Text("取消")) {
                    sessionToDelete = nil
                }
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                .foregroundColor(AgentClawDesign.secondaryText)
            ZStack(alignment: .leading) {
                if sidebarQuery.isEmpty {
                    Text("搜索历史")
                        .font(.system(size: 12))
                        .foregroundColor(AgentClawDesign.secondaryText)
                        .allowsHitTesting(false)
                }

                TextField("", text: $sidebarQuery)
                    .font(.system(size: 12))
                    .foregroundColor(AgentClawDesign.primaryText)
                    .accentColor(AgentClawDesign.accent)
                    .disableAutocorrection(true)
            }
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
                ZStack {
                    Color.white.opacity(0.5)
                        .frame(width: 34, height: 34)
                        .cornerRadius(8)

                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color.black)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                destination = .chat
                chatViewModel.createSession()
            }) {
                ZStack {
                    Color.white.opacity(0.5)
                        .frame(width: 34, height: 34)
                        .cornerRadius(8)

                    Image(systemName: "plus.bubble")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color.black)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Button(action: { isSettingsPresented = true }) {
                ZStack {
                    Color.white.opacity(0.5)
                        .frame(width: 34, height: 34)
                        .cornerRadius(8)

                    Image("slide_setting")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
            }
            .buttonStyle(PlainButtonStyle())
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

                Button(action: {
                    sessionToDelete = session
                    showDeleteAlert = true
                }) {
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
        isCustomIcon: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    if isCustomIcon {
                        Image(icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.black)
                    }
                }
                .frame(width: 20)

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
            .imageScale(.medium)
            .foregroundColor(AgentClawDesign.primaryText)
            .background(configuration.isPressed ? Color.black.opacity(0.08) : AgentClawDesign.controlSurface)
            .cornerRadius(8)
    }
}

struct DocumentsListView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @Binding var isPresented: Bool
    @State private var activeDocumentSheet: DocumentSheet?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private enum DocumentSheet: Identifiable {
        case preview(GeneratedDocument)
        case export(GeneratedDocument)

        var id: String {
            switch self {
            case .preview(let doc), .export(let doc):
                return doc.id
            }
        }
    }
    
    private var allDocuments: [GeneratedDocument] {
        chatViewModel.allDocuments.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        GeometryReader { proxy in
            let isCompact = horizontalSizeClass == .compact || proxy.size.width < 560
            let dialogHeight = isCompact ? proxy.size.height * 0.52 : min(proxy.size.height * 0.62, 500)
            
            ZStack {
                Color.black.opacity(0.18).edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        isPresented = false
                    }
                
                VStack(spacing: 0) {
                    // 标题栏
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("文件管理")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                            }
                            Text("所有对话生成的文档")
                                .font(.system(size: 11))
                                .foregroundColor(AgentClawDesign.secondaryText)
                        }
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                    
                    // 文档列表
                    if allDocuments.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(Color.gray.opacity(0.5))
                            Text("暂无生成的文档")
                                .font(.system(size: 14))
                                .foregroundColor(Color.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(allDocuments) { document in
                                    documentRow(document)
                                }
                            }
                            .padding(20)
                        }
                    }
                }
                .frame(maxWidth: isCompact ? proxy.size.width - 20 : proxy.size.width - 48)
                .frame(height: max(dialogHeight, isCompact ? 320 : 420))
                .background(Color(red: 0.98, green: 0.985, blue: 0.99))
                .cornerRadius(14)
                .padding(isCompact ? 8 : 24)
            }
        }
        .sheet(item: $activeDocumentSheet) { sheet in
            switch sheet {
            case .preview(let document):
                DocumentPreviewView(url: chatViewModel.generatedDocumentStore.fileURL(for: document))
            case .export(let document):
                DocumentExportView(url: chatViewModel.generatedDocumentStore.fileURL(for: document))
            }
        }
    }
    
    private func documentRow(_ document: GeneratedDocument) -> some View {
        Button(action: { activeDocumentSheet = .preview(document) }) {
            HStack(spacing: 12) {
                Image(systemName: documentIcon(for: document.displayName))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AgentClawDesign.accent)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text("点击预览")
                            .font(.system(size: 10))
                            .foregroundColor(AgentClawDesign.secondaryText)
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(AgentClawDesign.secondaryText)
                        Text(relativeTimeString(from: document.createdAt))
                            .font(.system(size: 10))
                            .foregroundColor(AgentClawDesign.secondaryText)
                    }
                }

                Spacer()

                Button(action: { activeDocumentSheet = .export(document) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                        Text("分享")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AgentClawDesign.accent)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func documentIcon(for fileName: String) -> String {
        let lower = fileName.lowercased()
        if lower.hasSuffix(".pdf") {
            return "doc.text.fill"
        } else if lower.hasSuffix(".docx") || lower.hasSuffix(".doc") {
            return "doc.fill"
        } else if lower.hasSuffix(".xlsx") || lower.hasSuffix(".xls") {
            return "tablecells.fill"
        } else if lower.hasSuffix(".pptx") || lower.hasSuffix(".ppt") {
            return "play.rectangle.fill"
        } else {
            return "doc.text.fill"
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: date)
        }
    }
}
