import SwiftUI
import UIKit

struct ShellView: View {
    private enum Destination {
        case chat, ideas, creation, profile
    }

    private enum ShellImagePickerSource: Int, Identifiable {
        case camera, gallery
        var id: Int { rawValue }
    }

    @ObservedObject private var gatewayViewModel: GatewayConnectionViewModel
    @ObservedObject private var chatViewModel: ChatViewModel
    @State private var isSidebarVisible = true
    @State private var isSettingsPresented = false
    @State private var isDocumentsPresented = false
    @State private var showLogin = false
    @State private var showVip = false
    @State private var sidebarQuery = ""
    // 应用启动（包括关闭开屏广告后）默认进入画图首页。
    @State private var destination: Destination = .creation
    @State private var sessionToDelete: LocalChatSession?
    @State private var showDeleteAlert = false
    // 生成期间切换/新建对话的二次确认（参考安卓 chat_switch 确认弹窗）
    @State private var pendingSessionAction: PendingSessionAction?
    @State private var showImagePickerOverlay = false
    @State private var activeImagePickerSource: ShellImagePickerSource?
    @State private var isAccountLoggedIn = {
        let preferences = AppPreferences()
        return preferences.isLoggedIn && !(preferences.userPhone?.isEmpty ?? true)
    }()
    @State private var accountPhone = AppPreferences().userPhone ?? ""

    init(container: DependencyContainer) {
        self.gatewayViewModel = GatewayConnectionViewModel(gatewayClient: container.gatewayClient)
        self.chatViewModel = ChatViewModel(
            gatewayClient: container.gatewayClient,
            preferences: container.preferences,
            generatedDocumentStore: container.generatedDocumentStore
        )
    }

    // Matches Android: sidebar hidden on CREATE/PROFILE, forced on IDEAS, toggle on CHAT
    private var effectiveSidebarVisible: Bool {
        switch destination {
        case .creation, .profile: return false
        case .ideas: return true
        case .chat: return isSidebarVisible
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HStack(spacing: 0) {
                    if effectiveSidebarVisible {
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

                if showLogin {
                    LoginView(
                        onLoggedIn: {
                            refreshAuthState()
                            withAnimation { showLogin = false }
                        },
                        onDismiss: { withAnimation { showLogin = false } }
                    )
                    .transition(.opacity)
                    .zIndex(8)
                }

                if showImagePickerOverlay {
                    ImagePickerOptionsOverlay(
                        onDismiss: { withAnimation { showImagePickerOverlay = false } },
                        onCamera: { presentRootImagePicker(.camera) },
                        onGallery: { presentRootImagePicker(.gallery) }
                    )
                    .zIndex(10)
                }

                Color.clear
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .sheet(item: $activeImagePickerSource) { source in
                        ImagePickerView(
                            sourceType: source == .camera ? .camera : .photoLibrary,
                            onImagePicked: { image in chatViewModel.attachImage(image) }
                        )
                    }
            }
        }
        .vipFullScreenCover(isPresented: $showVip) {
            VipView(isPresented: $showVip)
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            refreshAuthState()
        }
        .alert(item: $pendingSessionAction) { action in
            Alert(
                title: Text("确认切换对话?"),
                message: Text("当前回答仍在生成，是否先停止并切换？"),
                primaryButton: .default(Text("确定")) { performPendingSessionAction(action) },
                secondaryButton: .cancel(Text("取消"))
            )
        }
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

    // MARK: - Session switch / create (confirm while generating)

    private enum PendingSessionAction: Identifiable {
        case switchTo(LocalChatSession)
        case newSession
        var id: String {
            switch self {
            case .switchTo(let session): return "switch-\(session.id)"
            case .newSession: return "new"
            }
        }
    }

    /// 切换到某个对话：若当前正在生成且切换的是别的对话，先弹确认；否则直接切换。
    private func requestSelectSession(_ session: LocalChatSession) {
        destination = .chat
        guard session.id != chatViewModel.selectedSessionID else { return }
        if chatViewModel.isSending {
            pendingSessionAction = .switchTo(session)
        } else {
            chatViewModel.selectSession(session)
        }
    }

    /// 新建对话：生成期间先弹确认，否则直接新建。
    private func requestNewSession() {
        destination = .chat
        if chatViewModel.isSending {
            pendingSessionAction = .newSession
        } else {
            chatViewModel.createSession()
        }
    }

    private func performPendingSessionAction(_ action: PendingSessionAction) {
        chatViewModel.cancelGeneration()
        switch action {
        case .switchTo(let session):
            chatViewModel.selectSession(session)
        case .newSession:
            chatViewModel.createSession()
        }
    }

    // MARK: - Main Panel

    private var mainPanel: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider().background(AgentClawDesign.divider)
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().background(AgentClawDesign.divider)
            bottomTabBar
        }
        .background(AgentClawDesign.chatSurface)
        .cornerRadius(10)
    }

    // Content area — each destination is a separate panel (matches Android fragment container)
    private var contentArea: some View {
        Group {
            switch destination {
            case .chat:
                ChatView(
                    viewModel: chatViewModel,
                    onRequestImagePicker: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showImagePickerOverlay = true
                        }
                    }
                )
            case .ideas:
                FancyIdeasView { idea in
                    destination = .chat
                    chatViewModel.createSession(withDraft: idea.prompt)
                }
            case .creation:
                CreationGalleryView(
                    onLaunchImageChat: {
                        destination = .chat
                        chatViewModel.createSession(entryMode: .image)
                    },
                    onLaunchVideoChat: {
                        destination = .chat
                        chatViewModel.createSession(entryMode: .video)
                    }
                )
            case .profile:
                ProfileView(
                    isPresented: Binding(get: { true }, set: { _ in destination = .creation }),
                    showNavigation: false,
                    onOpenDocuments: { isDocumentsPresented = true },
                    onOpenSettings: { isSettingsPresented = true },
                    onOpenAccount: { withAnimation { showLogin = true } }
                )
            }
        }
    }

    // MARK: - Bottom Tab Bar (matches Android bottomNavigationBar)

    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            bottomTabItem(
                icon: "photo.on.rectangle.angled",
                label: "画图",
                isSelected: destination == .creation
            ) {
                destination = .creation
            }

            // 对话 tab is hidden when already on chat (matches Android)
            if destination != .chat {
                bottomTabItem(
                    icon: "bubble.left.and.bubble.right",
                    label: "对话",
                    isSelected: destination == .chat || destination == .ideas
                ) {
                    destination = .chat
                }
            }

            bottomTabItem(
                icon: "person.circle",
                label: "我的",
                isSelected: destination == .profile
            ) {
                destination = .profile
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 7)
        .padding(.bottom, 7)
        .frame(minHeight: 56)
        .modifier(TabBarStyleModifier())
    }

    private func bottomTabItem(
        icon: String,
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AgentClawDesign.accent : .gray)
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AgentClawDesign.accent : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.0 : 0.94)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    private func presentRootImagePicker(_ source: ShellImagePickerSource) {
        withAnimation { showImagePickerOverlay = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            activeImagePickerSource = source
        }
    }

    // MARK: - Chat Header (top bar in main panel)

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

            Button(action: { requestNewSession() }) {
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

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 12) {
            searchField

            Button(action: { requestNewSession() }) {
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

            // Bottom nav items (matches Android sidebar bottom section)
            VStack(spacing: 4) {
                sidebarNavItem(icon: "sparkles", title: "灵感泉涌", subtitle: "提示词模板") {
                    destination = .ideas
                }
                sidebarNavItem(icon: "folder", title: "文件", subtitle: "文件与分享") {
                    isDocumentsPresented = true
                }
                sidebarNavItem(
                    icon: "person.badge.key",
                    title: isAccountLoggedIn ? "账号" : "登录",
                    subtitle: isAccountLoggedIn ? maskedAccountPhone : "登录解锁"
                ) {
                    showLogin = true
                }
                sidebarNavItem(icon: "slide_setting", title: "设置", subtitle: "技能和关于", isCustomIcon: true) {
                    isSettingsPresented = true
                }

                // VIP card with golden gradient (matches Android bg_sidebar_vip_entry)
                Button(action: { showVip = true }) {
                    HStack(spacing: 10) {
                        Text("✦")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#F5D69D"))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("VIP 会员")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#F5D69D"))
                            Text("解锁满血 AI")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#C9AA79"))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#3A1F0D"), Color(hex: "#6B3A1F"), Color(hex: "#3A1F0D")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
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

    // MARK: - Helpers

    private var filteredSessions: [LocalChatSession] {
        let query = sidebarQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return chatViewModel.sessions }
        return chatViewModel.sessions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func sessionRow(_ session: LocalChatSession) -> some View {
        let selected = session.id == chatViewModel.selectedSessionID
        return HStack(spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "message")
                    .font(.system(size: 11))
                    .foregroundColor(selected ? AgentClawDesign.accent : AgentClawDesign.secondaryText)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .foregroundColor(AgentClawDesign.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(relativeDate(session.updatedAt))
                        .font(.system(size: 11))
                        .foregroundColor(AgentClawDesign.secondaryText)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                requestSelectSession(session)
            }

            Spacer(minLength: 0)

            Button(action: {
                sessionToDelete = session
                showDeleteAlert = true
            }) {
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(AgentClawDesign.secondaryText)
                }
                .frame(width: 28, height: 38)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(height: 38)
        .background(selected ? Color.white : Color.white.opacity(0.42))
        .cornerRadius(8)
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AgentClawDesign.primaryText)
                    Text(subtitle)
                        .font(.system(size: 11))
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

    private var maskedAccountPhone: String {
        guard accountPhone.count >= 7 else { return accountPhone.isEmpty ? "账号管理" : accountPhone }
        return String(accountPhone.prefix(3)) + "****" + String(accountPhone.suffix(4))
    }

    private func refreshAuthState() {
        let preferences = AppPreferences()
        isAccountLoggedIn = preferences.isLoggedIn && !(preferences.userPhone?.isEmpty ?? true)
        accountPhone = preferences.userPhone ?? ""
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct TabBarStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect()
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.42))
                        .frame(height: 0.5),
                    alignment: .top
                )
        } else {
            content
                .background(VisualEffectBlur(style: .systemUltraThinMaterialLight))
                .background(Color.white.opacity(0.48))
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.72))
                        .frame(height: 0.5),
                    alignment: .top
                )
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: -5)
        }
    }
}

private struct VisualEffectBlur: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
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
                    .onTapGesture { isPresented = false }

                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("文件管理")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                            }
                            Text("所有对话生成并保存的图片、视频和文件")
                                .font(.system(size: 12))
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

                    if allDocuments.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 48))
                                .foregroundColor(Color.gray.opacity(0.5))
                            Text("暂无保存的内容")
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
                            .font(.system(size: 12))
                            .foregroundColor(AgentClawDesign.secondaryText)
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundColor(AgentClawDesign.secondaryText)
                        Text(relativeTimeString(from: document.createdAt))
                            .font(.system(size: 12))
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
        if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") || lower.hasSuffix(".webp") || lower.hasSuffix(".heic") {
            return "photo.fill"
        }
        if lower.hasSuffix(".mp4") || lower.hasSuffix(".mov") || lower.hasSuffix(".m4v") {
            return "play.rectangle.fill"
        }
        if lower.hasSuffix(".pdf") { return "doc.text.fill" }
        if lower.hasSuffix(".docx") || lower.hasSuffix(".doc") { return "doc.fill" }
        if lower.hasSuffix(".xlsx") || lower.hasSuffix(".xls") { return "tablecells.fill" }
        if lower.hasSuffix(".pptx") || lower.hasSuffix(".ppt") { return "play.rectangle.fill" }
        return "doc.text.fill"
    }

    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        if interval < 604800 { return "\(Int(interval / 86400))天前" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
