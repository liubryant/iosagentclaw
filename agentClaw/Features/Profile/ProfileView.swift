import SwiftUI
import UIKit
import WebKit
import Combine

struct ProfileView: View {
    @Binding var isPresented: Bool
    var showNavigation: Bool = true
    var onOpenDocuments: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenAccount: (() -> Void)?

    @State private var showLogin = false
    @State private var showVip = false
    @State private var showLogoutAlert = false
    @State private var isLoggedIn = false
    @State private var userPhone: String? = nil
    @State private var isVipActive = false
    @State private var vipExpiresAt: String? = nil
    @State private var activeWebPage: LegalWebPage?
    @State private var showSetPassword = false
    @State private var showDeleteAccount = false

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private func fs(_ size: CGFloat) -> CGFloat { isPad ? ceil(size * 1.16) : size }

    private var maskedPhone: String {
        guard let phone = userPhone, phone.count >= 7 else { return userPhone ?? "" }
        return phone.prefix(3) + "****" + phone.suffix(4)
    }

    var body: some View {
        ZStack {
            Group {
                if showNavigation {
                    NavigationView { scrollContent }
                } else {
                    scrollContent
                }
            }

            if showLogin {
                LoginView(
                    onLoggedIn: {
                        refreshState()
                        withAnimation { showLogin = false }
                    },
                    onDismiss: { withAnimation { showLogin = false } }
                )
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .onAppear { refreshState() }
        .vipFullScreenCover(isPresented: $showVip) {
            VipView(isPresented: $showVip, onLoginRequired: { openAccount() })
        }
        .sheet(item: $activeWebPage) { page in
            InAppLegalWebView(page: page)
        }
        .sheet(isPresented: $showSetPassword) {
            SetPasswordView(phone: userPhone ?? "")
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView(phone: userPhone ?? "") {
                refreshState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            refreshState()
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("退出登录"),
                message: Text("确认退出当前登录账号？"),
                primaryButton: .destructive(Text("退出")) { doLogout() },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 27sp page title (matches Android profile_title)
                Text("我的")
                    .font(.system(size: fs(27), weight: .bold))
                    .foregroundColor(Color(hex: "#15151A"))
                    .padding(.bottom, 18)

                loginCard
                    .padding(.bottom, 14)

                serviceSection

                aboutSection

                if isLoggedIn {
                    accountSecuritySection
                    logoutSection
                        .padding(.top, 24)
                }

                versionFooter
                    .padding(.top, 20)
            }
            .padding(.horizontal, isPad ? 28 : 20)
            .padding(.top, isPad ? 22 : 16)
            .padding(.bottom, 28)
        }
        .background(Color(hex: "#FFFDFD").edgesIgnoringSafeArea(.all))
        .navigationBarTitle("我的", displayMode: .inline)
        .navigationBarItems(trailing: showNavigation ? AnyView(Button(action: { isPresented = false }) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)
        }) : AnyView(EmptyView()))
    }

    private func refreshState() {
        let p = AppPreferences()
        let rememberedPhone = p.userPhone
        let hasRememberedAccount = p.isLoggedIn && !(rememberedPhone?.isEmpty ?? true)
        if p.isLoggedIn && !hasRememberedAccount {
            p.logout()
        }
        isLoggedIn = hasRememberedAccount
        userPhone = rememberedPhone
        isVipActive = p.isVipActive
        vipExpiresAt = p.vipExpiresAt
    }

    // MARK: - Login Card (116dp, #F6F2FF, 24dp corners, matches Android loginCard)

    private var loginCard: some View {
        HStack(spacing: 16) {
            // Gradient circle avatar (bg_profile_avatar: angle=315, #7657F5→#C65FD0)
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#7657F5"), Color(hex: "#C65FD0")],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                Image(systemName: "person.fill")
                    .font(.system(size: fs(26)))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(isLoggedIn && !(userPhone?.isEmpty ?? true) ? maskedPhone : "登录Agent智能体")
                    .font(.system(size: fs(19), weight: .semibold))
                    .foregroundColor(Color(hex: "#19191F"))
                    .lineLimit(1)
                Text(isLoggedIn ? "账号已登录" : "登录后享受完整AI功能")
                    .font(.system(size: fs(12)))
                    .foregroundColor(Color(hex: "#73727E"))
            }

            Spacer()

            if !isLoggedIn {
                Button(action: { openAccount() }) {
                    Text("登录")
                        .font(.system(size: fs(13), weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .frame(minWidth: 72)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#7658F7"), Color(hex: "#A64EE4")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(19)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Text("账号")
                    .font(.system(size: fs(13), weight: .medium))
                    .foregroundColor(Color(hex: "#6750F5"))
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(19)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: isPad ? 136 : 116)
        .background(Color(hex: "#F6F2FF"))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "#6750F5").opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture { openAccount() }
    }

    // MARK: - VIP Card (134dp, dark brown gradient, matches Android vipCard)

    private var vipCard: some View {
        VStack(spacing: 0) {
            // Top row
            HStack(spacing: 14) {
                // VIP icon (bg_profile_vip_icon: oval, angle=315, #FFE3A7→#C9944F)
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "#FFE3A7"), Color(hex: "#C9944F")],
                        startPoint: .topTrailing, endPoint: .bottomLeading
                    )
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    Text("✦")
                        .font(.system(size: fs(21)))
                        .foregroundColor(Color(hex: "#4B2A12"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Agent智能体会员")
                        .font(.system(size: fs(17), weight: .bold))
                        .foregroundColor(Color(hex: "#FFF2D2"))
                    Group {
                        if isVipActive, let exp = vipExpiresAt {
                            Text("有效期至 \(exp)")
                        } else {
                            Text(isLoggedIn ? "开通会员，解锁AI助手全部功能" : "登录后开通会员享受完整权益")
                        }
                    }
                    .font(.system(size: fs(11)))
                    .foregroundColor(Color(hex: "#C8A97E"))
                }

                Spacer()

                // Action button
                Text("查看权益")
                    .font(.system(size: fs(12), weight: .semibold))
                    .foregroundColor(Color(hex: "#4F2D16"))
                    .padding(.horizontal, 15)
                    .frame(height: 34)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#FFE9BD"), Color(hex: "#DAB06F")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(17)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            Spacer()

            // Divider (#22FFFFFF = 13.3% white, marginTop=10dp, marginBottom=10dp)
            Rectangle()
                .fill(Color.white.opacity(0.133))
                .frame(height: 1)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 10)

            // Benefits row with vertical dividers
            HStack(spacing: 0) {
                Text("✦ AI 图像生成")
                    .font(.system(size: fs(11)))
                    .foregroundColor(Color(hex: "#EECC9A"))
                    .frame(maxWidth: .infinity)
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 12)
                Text("✦ AI 视频生成")
                    .font(.system(size: fs(11)))
                    .foregroundColor(Color(hex: "#EECC9A"))
                    .frame(maxWidth: .infinity)
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 12)
                Text("✦ 无限对话")
                    .font(.system(size: fs(11)))
                    .foregroundColor(Color(hex: "#EECC9A"))
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 14)
        }
        .frame(height: isPad ? 158 : 134)
        .background(
            LinearGradient(
                colors: [Color(hex: "#241B18"), Color(hex: "#3B2920"), Color(hex: "#5A402B")],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .cornerRadius(22)
        .onTapGesture {
            if isLoggedIn { showVip = true } else { showLogin = true }
        }
    }

    // MARK: - Service Section

    private var serviceSection: some View {
        VStack(spacing: 0) {
            sectionHeader("常用服务")
            VStack(spacing: 0) {
                profileRow(icon: "folder.fill", title: "文件", iconColor: Color(hex: "#6750F5")) {
                    if let cb = onOpenDocuments { cb() }
                }
                sectionDivider
                profileRow(icon: "gearshape.fill", title: "设置", iconColor: Color(hex: "#3E9DA8")) {
                    if let cb = onOpenSettings { cb() }
                }
            }
            .background(Color(hex: "#F8F8FA"))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 0) {
            sectionHeader("关于")
            VStack(spacing: 0) {
                profileRow(icon: "doc.text.fill", title: "用户协议", iconColor: Color(hex: "#596DDF")) {
                    openWebPage(title: "用户协议", url: "https://www.cjym123.cn/agreement_agentclaw.html")
                }
                sectionDivider
                profileRow(icon: "shield.fill", title: "隐私政策", iconColor: Color(hex: "#44A57A")) {
                    openWebPage(title: "隐私政策", url: "https://www.cjym123.cn/privacy_agentclaw.html")
                }
                sectionDivider
                profileRow(icon: "bubble.left.fill", title: "客服反馈", iconColor: Color(hex: "#3B82F6")) {
                    openWebPage(title: "客服反馈", url: "https://www.cjym123.cn/feedback_agentclaw.html")
                }
            }
            .background(Color(hex: "#F8F8FA"))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
    }

    // MARK: - Logout Section

    private var accountSecuritySection: some View {
        VStack(spacing: 0) {
            sectionHeader("账号与安全")
            VStack(spacing: 0) {
                profileRow(icon: "key.fill", title: "修改密码", iconColor: Color(hex: "#6750F5")) {
                    showSetPassword = true
                }
                sectionDivider
                profileRow(icon: "person.crop.circle.badge.xmark", title: "注销账号", iconColor: Color(hex: "#E5484D")) {
                    showDeleteAccount = true
                }
            }
            .background(Color(hex: "#F8F8FA"))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
    }

    private var logoutSection: some View {
        Button(action: doLogout) {
            HStack {
                Spacer()
                Text("退出登录")
                    .font(.system(size: fs(15)))
                    .foregroundColor(Color(hex: "#E8463A"))
                Spacer()
            }
            .frame(height: isPad ? 64 : 56)
            .background(Color(hex: "#F8F8FA"))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var versionFooter: some View {
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        return Text("Agent智能体 v\(version)")
            .font(.system(size: fs(11)))
            .foregroundColor(Color(hex: "#A0A0AA"))
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: fs(17), weight: .bold))
                .foregroundColor(Color(hex: "#202027"))
            Spacer()
        }
        .padding(.leading, 4)
        .padding(.top, 24)
        .padding(.bottom, 9)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.05))
            .frame(height: 1)
            .padding(.leading, 54)
    }

    private func profileRow(icon: String, title: String, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: fs(16)))
                    .foregroundColor(iconColor)
                    .frame(width: 26, height: 26)
                Text(title)
                    .font(.system(size: fs(15)))
                    .foregroundColor(Color(hex: "#26262D"))
                Spacer()
                Text("›")
                    .font(.system(size: fs(25)))
                    .foregroundColor(Color(hex: "#A3A3AB"))
            }
            .padding(.horizontal, 16)
            .frame(height: isPad ? 66 : 58)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func doLogout() {
        AppPreferences().logout()
        refreshState()
        NotificationCenter.default.post(name: .authStateDidChange, object: nil)
    }

    private func openAccount() {
        if let onOpenAccount = onOpenAccount {
            onOpenAccount()
        } else {
            withAnimation { showLogin = true }
        }
    }

    private func openWebPage(title: String, url: String) {
        guard let pageURL = URL(string: url) else { return }
        activeWebPage = LegalWebPage(title: title, url: pageURL)
    }

}

struct LegalWebPage: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

struct InAppLegalWebView: View {
    let page: LegalWebPage
    var onClose: (() -> Void)? = nil
    @Environment(\.presentationMode) private var presentationMode
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var reloadID = UUID()

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)

                LegalWKWebView(url: page.url, isLoading: $isLoading, errorMessage: $errorMessage)
                    .id(reloadID)

                if isLoading {
                    VStack(spacing: 12) {
                        CompatProgressView()
                        Text("正在加载…")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.92))
                    .cornerRadius(14)
                }

                if let errorMessage = errorMessage, !isLoading {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 30))
                            .foregroundColor(Color(hex: "#6750F5"))
                        Text("页面加载失败")
                            .font(.system(size: 17, weight: .semibold))
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                        Button("重新加载") {
                            self.errorMessage = nil
                            isLoading = true
                            reloadID = UUID()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .frame(height: 40)
                        .background(Color(hex: "#6750F5"))
                        .cornerRadius(20)
                    }
                    .padding(24)
                }
            }
            .navigationBarTitle(Text(page.title), displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                if let onClose = onClose {
                    onClose()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#202027"))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct LegalWKWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: LegalWKWebView

        init(parent: LegalWKWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.errorMessage = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finishWith(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finishWith(error)
        }

        private func finishWith(_ error: Error) {
            parent.isLoading = false
            parent.errorMessage = error.localizedDescription
        }
    }
}

struct DeleteAccountView: View {
    let phone: String
    var onDeleted: (() -> Void)?

    @Environment(\.presentationMode) private var presentationMode
    @State private var code = ""
    @State private var countdown = 0
    @State private var isSendingCode = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showFinalConfirmation = false
    @State private var countdownTimer: AnyCancellable?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("注销账号")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(hex: "#202027"))
                        Text("验证手机号 \(maskedPhone) 后将永久注销账号")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("注销账号前请确认：")
                            .font(.system(size: 14, weight: .semibold))
                        Text("• 账号信息及相关数据将被永久删除，无法恢复。\n• 注销后该手机号可重新注册新账号。")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#765A3B"))
                            .lineSpacing(4)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#FFF7ED"))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("短信验证码")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("请输入6位验证码", text: Binding(
                                get: { code },
                                set: { code = String($0.filter { $0.isNumber }.prefix(6)) }
                            ))
                            .keyboardType(.numberPad)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#202027"))
                            .accentColor(Color(hex: "#6750F5"))
                            .environment(\.colorScheme, .light)

                            Button(action: sendCode) {
                                Text(countdown > 0 ? "\(countdown)s" : (isSendingCode ? "发送中…" : "获取验证码"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(canSendCode ? Color(hex: "#6750F5") : Color(hex: "#5F6470"))
                                    .frame(width: 82)
                            }
                            .disabled(!canSendCode)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(Color(hex: "#F7F5FA"))
                        .cornerRadius(12)
                    }

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#E5484D"))
                    }

                    Button(action: { showFinalConfirmation = true }) {
                        ZStack {
                            if isDeleting {
                                CompatProgressView()
                            } else {
                                Text("注销账号")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(canDelete ? Color(hex: "#E5484D") : Color.gray.opacity(0.4))
                        .cornerRadius(14)
                    }
                    .disabled(!canDelete)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitle(Text("注销账号"), displayMode: .inline)
            .navigationBarItems(leading: Button("取消") { presentationMode.wrappedValue.dismiss() })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert(isPresented: $showFinalConfirmation) {
            Alert(
                title: Text("确认注销账号？"),
                message: Text("注销后账号及数据将被永久删除，且无法恢复。"),
                primaryButton: .destructive(Text("确认注销"), action: deleteAccount),
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .onDisappear { countdownTimer?.cancel() }
    }

    private var maskedPhone: String {
        guard phone.count >= 7 else { return phone }
        return String(phone.prefix(3)) + "****" + String(phone.suffix(4))
    }

    private var canSendCode: Bool {
        phone.count == 11 && countdown == 0 && !isSendingCode && !isDeleting
    }

    private var canDelete: Bool {
        code.count == 6 && !isDeleting
    }

    private func sendCode() {
        guard canSendCode else { return }
        isSendingCode = true
        errorMessage = nil
        Task {
            do {
                try await AuthService.shared.sendCode(phone: phone)
                await MainActor.run {
                    isSendingCode = false
                    startCountdown()
                }
            } catch {
                await MainActor.run {
                    isSendingCode = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func deleteAccount() {
        guard canDelete else { return }
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await AuthService.shared.deleteAccount(phone: phone, code: code)
                await MainActor.run {
                    AppPreferences().logout()
                    NotificationCenter.default.post(name: .authStateDidChange, object: nil)
                    isDeleting = false
                    onDeleted?()
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startCountdown() {
        countdownTimer?.cancel()
        countdown = 120
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if countdown > 0 {
                    countdown -= 1
                } else {
                    countdownTimer?.cancel()
                }
            }
    }
}
