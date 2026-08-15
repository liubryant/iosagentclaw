import SwiftUI
import UIKit

struct ShellView: View {
    private enum Destination {
        case chat, ideas, creation, avatar, profile
    }

    private enum ShellImagePickerSource: Int, Identifiable {
        case camera, gallery
        var id: Int { rawValue }
    }

    @ObservedObject private var gatewayViewModel: GatewayConnectionViewModel
    @ObservedObject private var chatViewModel: ChatViewModel
    @StateObject private var avatarViewModel: AvatarViewModel
    @AppStorage("agentClaw.sidebar.isVisible") private var isSidebarVisible = false
    @State private var isSettingsPresented = false
    @State private var isDocumentsPresented = false
    @State private var showLogin = false
    @State private var showVip = false
    @State private var sidebarQuery = ""
    // 应用启动（包括关闭开屏广告后）默认进入画图首页。
    @State private var destination: Destination = .creation
    @State private var sessionToDelete: LocalChatSession?
    @State private var activeShellAlert: ShellAlert?
    // 生成期间切换/新建对话的二次确认（参考安卓 chat_switch 确认弹窗）
    @State private var pendingSessionAction: PendingSessionAction?
    @State private var showImagePickerOverlay = false
    @State private var activeImagePickerSource: ShellImagePickerSource?
    @State private var activeCameraImagePickerSource: ShellImagePickerSource?
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
        _avatarViewModel = StateObject(wrappedValue: AvatarViewModel(gatewayClient: container.gatewayClient))
    }

    // Sidebar belongs to the conversation workspace and stays above the bottom tab bar.
    private var effectiveSidebarVisible: Bool {
        switch destination {
        case .creation, .avatar, .profile: return false
        case .ideas: return true
        case .chat: return isSidebarVisible
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                ZStack {
                    HStack(spacing: 0) {
                        if effectiveSidebarVisible {
                            sidebar
                                .frame(width: sidebarWidth(for: proxy.size.width))
                                .transition(.move(edge: .leading))
                        }

                        mainPanel
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(destination == .avatar ? 0 : 4)
                    }
                    .background(
                        (usesWhitePageBackground ? Color.white : AgentClawDesign.appBackground)
                            .edgesIgnoringSafeArea(.all)
                    )

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
                            cameraAvailability: ImageCaptureAvailability.camera,
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
                        .fullScreenCover(item: $activeCameraImagePickerSource) { source in
                            ImagePickerView(
                                sourceType: source == .camera ? .camera : .photoLibrary,
                                onImagePicked: { image in chatViewModel.attachImage(image) }
                            )
                        }
                }
                .modifier(AvatarTopImmersiveModifier(isEnabled: destination == .avatar))
                .padding(.bottom, extendsBehindBottomTab ? 0 : 50)
                .ignoresSafeArea(.container, edges: extendsBehindBottomTab ? .bottom : [])

                bottomTabBar
                    .zIndex(20)
            }
        }
        .modifier(AvatarTopImmersiveModifier(isEnabled: destination == .avatar))
        .modifier(IPadReadableTypeModifier())
        .vipFullScreenCover(isPresented: $showVip) {
            VipView(isPresented: $showVip)
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            refreshAuthState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .agentClawQuickAction)) { notification in
            if let action = notification.object as? AgentClawQuickAction {
                _ = QuickActionRouter.shared.consumePendingAction()
                handleQuickAction(action)
            }
        }
        .onAppear {
            Task { await QuotaManager.shared.refreshServerQuota() }
            if let action = QuickActionRouter.shared.consumePendingAction() {
                handleQuickAction(action)
            }
            avatarViewModel.digitalHuman.setPageVisible(destination == .avatar)
        }
        .onChange(of: destination) { newDestination in
            avatarViewModel.digitalHuman.setPageVisible(newDestination == .avatar)
        }
        .alert(item: $activeShellAlert) { alert in
            switch alert {
            case .pendingAction(let action):
                return Alert(
                    title: Text("确认切换对话?"),
                    message: Text("当前回答仍在生成，是否先停止并切换？"),
                    primaryButton: .default(Text("确定")) { performPendingSessionAction(action) },
                    secondaryButton: .cancel(Text("取消")) { pendingSessionAction = nil }
                )
            case .deleteSession(let session):
                return Alert(
                    title: Text("删除对话"),
                    message: Text("确定要删除这个对话吗？此操作无法撤销。"),
                    primaryButton: .destructive(Text("删除")) {
                        chatViewModel.deleteSession(session)
                        sessionToDelete = nil
                    },
                    secondaryButton: .cancel(Text("取消")) {
                        sessionToDelete = nil
                    }
                )
            case .message(let title, let message):
                return Alert(title: Text(title), message: Text(message), dismissButton: .default(Text("知道了")))
            }
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

    private enum ShellAlert: Identifiable {
        case pendingAction(PendingSessionAction)
        case deleteSession(LocalChatSession)
        case message(title: String, message: String)

        var id: String {
            switch self {
            case .pendingAction(let action): return "pending-\(action.id)"
            case .deleteSession(let session): return "delete-\(session.id)"
            case .message(let title, let message): return "message-\(title)-\(message)"
            }
        }
    }

    /// 切换到某个对话：若当前正在生成且切换的是别的对话，先弹确认；否则直接切换。
    private func requestSelectSession(_ session: LocalChatSession) {
        destination = .chat
        guard session.id != chatViewModel.selectedSessionID else { return }
        if chatViewModel.isSending {
            pendingSessionAction = .switchTo(session)
            activeShellAlert = .pendingAction(.switchTo(session))
        } else {
            chatViewModel.selectSession(session)
        }
    }

    /// 新建对话：生成期间先弹确认，否则直接新建。
    private func requestNewSession() {
        destination = .chat
        if chatViewModel.isSending {
            pendingSessionAction = .newSession
            activeShellAlert = .pendingAction(.newSession)
        } else {
            chatViewModel.createSession()
        }
    }

    private func performPendingSessionAction(_ action: PendingSessionAction) {
        pendingSessionAction = nil
        chatViewModel.cancelGeneration()
        switch action {
        case .switchTo(let session):
            chatViewModel.selectSession(session)
        case .newSession:
            chatViewModel.createSession()
        }
    }

    private func handleQuickAction(_ action: AgentClawQuickAction) {
        switch action {
        case .avatar:
            destination = .avatar
        case .image:
            destination = .chat
            chatViewModel.createSession(entryMode: .image)
        }
    }

    private func selectDestination(_ newDestination: Destination) {
        #if DEBUG
        print("duix tab_select from=\(String(describing: destination)) to=\(String(describing: newDestination)) uptime=\(String(format: "%.3f", ProcessInfo.processInfo.systemUptime))")
        #endif
        destination = newDestination
    }

    // MARK: - Main Panel

    private var mainPanel: some View {
        VStack(spacing: 0) {
            // Keep a stable SwiftUI hierarchy. Inserting/removing the header used to
            // recreate the nested UIViewRepresentable and therefore the Duix host view.
            chatHeader
                .frame(height: hidesChatHeader ? 0 : nil)
                .opacity(hidesChatHeader ? 0 : 1)
                .clipped()
            Divider()
                .background(AgentClawDesign.divider)
                .frame(height: hidesChatHeader ? 0 : 1)
                .opacity(hidesChatHeader ? 0 : 1)
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            destination == .avatar
                ? Color.clear
                : (usesWhitePageBackground ? Color.white : AgentClawDesign.chatSurface)
        )
        .cornerRadius(destination == .avatar ? 0 : 10)
    }

    private var hidesChatHeader: Bool {
        destination == .creation || destination == .avatar || destination == .profile
    }

    private var usesWhitePageBackground: Bool {
        destination == .creation || destination == .profile
    }

    private var extendsBehindBottomTab: Bool {
        destination == .creation || destination == .profile
    }

    // Content area — each destination is a separate panel (matches Android fragment container)
    private var contentArea: some View {
        Color.clear
        .overlay(
            ChatView(
                viewModel: chatViewModel,
                onRequestImagePicker: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showImagePickerOverlay = true
                    }
                }
            )
            .opacity(destination == .chat ? 1 : 0)
            .allowsHitTesting(destination == .chat)
            .accessibilityHidden(destination != .chat)
        )
        .overlay(
            FancyIdeasView { idea in
                destination = .chat
                chatViewModel.createSession(withDraft: idea.prompt)
            }
            .opacity(destination == .ideas ? 1 : 0)
            .allowsHitTesting(destination == .ideas)
            .accessibilityHidden(destination != .ideas)
        )
        .overlay(
            ProfileView(
                isPresented: Binding(get: { true }, set: { _ in destination = .creation }),
                showNavigation: false,
                onOpenDocuments: { isDocumentsPresented = true },
                onOpenSettings: { isSettingsPresented = true },
                onOpenAccount: { withAnimation { showLogin = true } }
            )
            .opacity(destination == .profile ? 1 : 0)
            .allowsHitTesting(destination == .profile)
            .accessibilityHidden(destination != .profile)
        )
        // Every page is attached to this stable root. Opacity changes visibility while
        // overlays avoid contributing an intrinsic width to the sidebar HStack.
        .overlay(
            CreationGalleryView(
                onLaunchImageChat: { prompt in
                    destination = .chat
                    if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        chatViewModel.createSession(entryMode: .image)
                    } else {
                        chatViewModel.createSession(withDraft: prompt, entryMode: .image)
                    }
                },
                onLaunchVideoChat: {
                    destination = .chat
                    chatViewModel.createSession(entryMode: .video)
                }
            )
            .opacity(destination == .creation ? 1 : 0)
            .allowsHitTesting(destination == .creation)
            .accessibilityHidden(destination != .creation)
        )
        // Lily also remains alive, but no longer establishes a minimum content width.
        .overlay(
            AvatarView(viewModel: avatarViewModel)
                .opacity(destination == .avatar ? 1 : 0)
                .allowsHitTesting(destination == .avatar)
                .accessibilityHidden(destination != .avatar)
        )
    }

    // MARK: - Bottom Tab Bar (matches Android bottomNavigationBar)

    private var bottomTabBar: some View {
        NativeAgentTabBar(
            selectedIndex: currentBottomTabIndex,
            onSelect: { index in
                switch index {
                case 0: selectDestination(.creation)
                case 1: selectDestination(.chat)
                case 2: selectDestination(.avatar)
                case 3: selectDestination(.profile)
                default: break
                }
            }
        )
        .frame(height: 50)
        .offset(y: 12)
    }

    private var currentBottomTabIndex: Int {
        switch destination {
        case .creation: return 0
        case .chat, .ideas: return 1
        case .avatar: return 2
        case .profile: return 3
        }
    }

    private func presentRootImagePicker(_ source: ShellImagePickerSource) {
        withAnimation { showImagePickerOverlay = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if source == .camera {
                ImageCaptureAvailability.requestCameraAccessIfNeeded { availability in
                    guard availability.isAvailable else {
                        activeShellAlert = .message(title: "无法拍照", message: availability.message)
                        return
                    }
                    activeCameraImagePickerSource = source
                }
            } else {
                activeImagePickerSource = source
            }
        }
    }

    // MARK: - Chat Header (top bar in main panel)

    private var chatHeader: some View {
        HStack(spacing: 8) {
            if destination == .chat || destination == .ideas {
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
            }

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
                .font(.system(size: 13, weight: .semibold))
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
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "#F5D69D"))
                            Text("解锁满血 AI")
                                .font(.system(size: 12))
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
                .font(.system(size: 13))
                .foregroundColor(AgentClawDesign.secondaryText)
            ZStack(alignment: .leading) {
                if sidebarQuery.isEmpty {
                    Text("搜索历史")
                        .font(.system(size: 13))
                        .foregroundColor(AgentClawDesign.secondaryText)
                        .allowsHitTesting(false)
                }
                TextField("", text: $sidebarQuery)
                    .font(.system(size: 13))
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
            Button(action: { requestSelectSession(session) }) {
                HStack(spacing: 10) {
                    Image(systemName: "message")
                        .font(.system(size: 13))
                        .foregroundColor(selected ? AgentClawDesign.accent : AgentClawDesign.secondaryText)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.title)
                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                            .foregroundColor(AgentClawDesign.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Text(relativeDate(session.updatedAt))
                            .font(.system(size: 12))
                            .foregroundColor(AgentClawDesign.secondaryText)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                sessionToDelete = session
                activeShellAlert = .deleteSession(session)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(AgentClawDesign.secondaryText)
                    .frame(width: 44, height: 38)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.leading, 8)
        .padding(.trailing, 0)
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
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color.black)
                    }
                }
                .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AgentClawDesign.primaryText)
                    Text(subtitle)
                        .font(.system(size: 12))
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

private struct AvatarTopImmersiveModifier: ViewModifier {
    let isEnabled: Bool
    func body(content: Content) -> some View {
        // Keep the modified subtree's identity stable while switching tabs. Returning
        // different view types from an if/else causes SwiftUI to rebuild the embedded
        // Duix UIViewRepresentable and bind the renderer to a new host view.
        content.ignoresSafeArea(.container, edges: isEnabled ? .top : [])
    }
}

private struct IPadReadableTypeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content.dynamicTypeSize(.xLarge)
        } else {
            content
        }
    }
}

private struct NativeAgentTabBar: UIViewRepresentable {
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> UITabBar {
        let tabBar = UITabBar()
        tabBar.delegate = context.coordinator
        tabBar.isTranslucent = true
        tabBar.tintColor = .systemBlue
        tabBar.unselectedItemTintColor = .secondaryLabel

        let drawingIcon = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        let chatIcon = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let profileIcon = UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)
        let definitions: [(String, UIImage?)] = [
            ("画图", UIImage(systemName: "photo.on.rectangle.angled", withConfiguration: drawingIcon)),
            ("对话", UIImage(systemName: "bubble.left.and.bubble.right", withConfiguration: chatIcon)),
            ("智能体", Self.avatarTabImage()),
            ("我的", UIImage(systemName: "person.circle", withConfiguration: profileIcon))
        ]

        tabBar.items = definitions.enumerated().map { index, definition in
            let item = UITabBarItem(
                title: definition.0,
                image: definition.1,
                selectedImage: nil
            )
            item.tag = index
            return item
        }
        if let items = tabBar.items, items.indices.contains(selectedIndex) {
            tabBar.selectedItem = items[selectedIndex]
        }
        return tabBar
    }

    private static func avatarTabImage() -> UIImage? {
        guard let source = UIImage(named: "avatar_agent_tab_icon") else { return nil }
        let size = CGSize(width: 24, height: 24)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.addEllipse(in: rect)
            context.cgContext.clip()

            let scale = max(size.width / source.size.width, size.height / source.size.height)
            let drawSize = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            let drawOrigin = CGPoint(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2
            )
            source.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
        .withRenderingMode(.alwaysOriginal)
    }

    func updateUIView(_ tabBar: UITabBar, context: Context) {
        context.coordinator.onSelect = onSelect
        if let items = tabBar.items,
           items.indices.contains(selectedIndex),
           tabBar.selectedItem !== items[selectedIndex] {
            tabBar.selectedItem = items[selectedIndex]
        }
    }

    final class Coordinator: NSObject, UITabBarDelegate {
        var onSelect: (Int) -> Void

        init(onSelect: @escaping (Int) -> Void) {
            self.onSelect = onSelect
        }

        func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
            onSelect(item.tag)
        }
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
