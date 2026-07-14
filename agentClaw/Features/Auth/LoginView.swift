import SwiftUI
import Combine

final class LoginViewModel: ObservableObject {
    @Published var phone = ""
    @Published var code = ""
    @Published var password = ""
    @Published var isCodeMode = true
    @Published var countdown = 0
    @Published var isLoading = false
    @Published var errorMsg: String?

    var onLoggedIn: (() -> Void)?
    private var countdownTimer: AnyCancellable?

    var canSendCode: Bool { phone.count == 11 && countdown == 0 && !isLoading }
    var canLogin: Bool {
        isCodeMode
            ? phone.count == 11 && code.count == 6 && !isLoading
            : phone.count == 11 && password.count >= 6 && !isLoading
    }

    func sendCode() {
        guard canSendCode else { return }
        isLoading = true
        errorMsg = nil
        Task {
            do {
                try await AuthService.shared.sendCode(phone: phone)
                await MainActor.run {
                    self.isLoading = false
                    self.startCountdown()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMsg = error.localizedDescription
                }
            }
        }
    }

    func login() {
        if isCodeMode { loginByCode() } else { loginByPassword() }
    }

    private func loginByCode() {
        guard phone.count == 11 && code.count == 6 && !isLoading else { return }
        isLoading = true
        errorMsg = nil
        Task {
            do {
                let result = try await AuthService.shared.loginByCode(phone: phone, code: code)
                let prefs = AppPreferences()
                prefs.isLoggedIn = true
                prefs.userPhone = result.phone
                if !result.accessToken.isEmpty { prefs.userAccessToken = result.accessToken }
                await MainActor.run {
                    self.isLoading = false
                    NotificationCenter.default.post(name: .authStateDidChange, object: nil)
                    self.onLoggedIn?()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMsg = error.localizedDescription
                }
            }
        }
    }

    private func loginByPassword() {
        guard phone.count == 11 && password.count >= 6 && !isLoading else { return }
        isLoading = true
        errorMsg = nil
        Task {
            do {
                let result = try await AuthService.shared.loginByPassword(phone: phone, password: password)
                let prefs = AppPreferences()
                prefs.isLoggedIn = true
                prefs.userPhone = result.phone
                if !result.accessToken.isEmpty { prefs.userAccessToken = result.accessToken }
                await MainActor.run {
                    self.isLoading = false
                    NotificationCenter.default.post(name: .authStateDidChange, object: nil)
                    self.onLoggedIn?()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMsg = error.localizedDescription
                }
            }
        }
    }

    private func startCountdown() {
        countdown = 60
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.countdown > 0 {
                    self.countdown -= 1
                } else {
                    self.countdownTimer?.cancel()
                }
            }
    }
}

struct LoginView: View {
    var onLoggedIn: (() -> Void)?
    var onDismiss: (() -> Void)?
    @StateObject private var vm: LoginViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var isLoggedIn: Bool
    @State private var showSetPassword = false

    init(onLoggedIn: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self.onLoggedIn = onLoggedIn
        self.onDismiss = onDismiss
        _vm = StateObject(wrappedValue: LoginViewModel())
        let prefs = AppPreferences()
        _isLoggedIn = State(initialValue: prefs.isLoggedIn && !(prefs.userPhone?.isEmpty ?? true))
    }

    var body: some View {
        Group {
            if isLoggedIn {
                accountContent
            } else {
                NavigationView {
                    VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#6750F5"), Color(hex: "#9B7BFE")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                        Text("✦")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 32)

                    Text("登录账号")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "#1A1A2E"))
                    Text(vm.isCodeMode ? "手机验证码快速登录" : "手机号密码登录")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 32)

                VStack(spacing: 16) {
                    // Phone input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("手机号")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                        HStack {
                            Text("+86")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: "#6750F5"))
                            Divider().frame(height: 20)
                            TextField("请输入手机号", text: Binding(
                                get: { vm.phone },
                                set: { vm.phone = String($0.prefix(11)) }
                            ))
                                .keyboardType(.numberPad)
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#1A1A2E"))
                                .accentColor(Color(hex: "#6750F5"))
                                .environment(\.colorScheme, .light)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Color(hex: "#F6F2FF"))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#6750F5").opacity(0.2), lineWidth: 1)
                        )
                    }

                    if vm.isCodeMode {
                        // Code input
                        VStack(alignment: .leading, spacing: 6) {
                            Text("验证码")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                            HStack {
                                TextField("请输入6位验证码", text: Binding(
                                    get: { vm.code },
                                    set: { vm.code = String($0.prefix(6)) }
                                ))
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(hex: "#1A1A2E"))
                                    .accentColor(Color(hex: "#6750F5"))
                                    .environment(\.colorScheme, .light)
                                Divider().frame(height: 20)
                                Button(action: { vm.sendCode() }) {
                                    if vm.countdown > 0 {
                                        Text("\(vm.countdown)s")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(hex: "#5F6470"))
                                            .frame(width: 72)
                                    } else {
                                        Text("获取验证码")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(vm.canSendCode ? Color(hex: "#6750F5") : Color(hex: "#5F6470"))
                                            .frame(width: 72)
                                    }
                                }
                                .disabled(!vm.canSendCode)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(Color(hex: "#F6F2FF"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#6750F5").opacity(0.2), lineWidth: 1)
                            )
                        }
                    } else {
                        // Password input
                        VStack(alignment: .leading, spacing: 6) {
                            Text("密码")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                            SecureField("请输入密码（6位以上）", text: $vm.password)
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#1A1A2E"))
                                .accentColor(Color(hex: "#6750F5"))
                                .environment(\.colorScheme, .light)
                                .padding(.horizontal, 14)
                                .frame(height: 48)
                                .background(Color(hex: "#F6F2FF"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#6750F5").opacity(0.2), lineWidth: 1)
                                )
                        }
                    }

                    // Error message
                    if let err = vm.errorMsg {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Login button
                    Button(action: {
                        vm.onLoggedIn = {
                            dismissView()
                            onLoggedIn?()
                        }
                        vm.login()
                    }) {
                        ZStack {
                            if vm.isLoading {
                                CompatProgressView()
                            } else {
                                Text("登录")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            vm.canLogin
                            ? LinearGradient(colors: [Color(hex: "#6750F5"), Color(hex: "#9B7BFE")], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                    }
                    .disabled(!vm.canLogin || vm.isLoading)
                    .padding(.top, 8)

                    // Mode toggle
                    Button(action: {
                        vm.isCodeMode.toggle()
                        vm.errorMsg = nil
                    }) {
                        Text(vm.isCodeMode ? "使用密码登录" : "使用验证码登录")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#6750F5"))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 28)

                Spacer()

                Text("登录即代表您同意《用户协议》和《隐私政策》")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
                    }
                    .navigationBarTitle("", displayMode: .inline)
                    .navigationBarItems(leading: Button("取消") {
                        dismissView()
                    })
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
        .sheet(isPresented: $showSetPassword) {
            SetPasswordView(phone: AppPreferences().userPhone ?? "")
        }
        .onAppear {
            let prefs = AppPreferences()
            isLoggedIn = prefs.isLoggedIn && !(prefs.userPhone?.isEmpty ?? true)
        }
    }

    private var accountContent: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 560
            let dialogHeight = isCompact
                ? max(proxy.size.height * 0.52, 320)
                : min(max(proxy.size.height * 0.62, 420), 500)

            ZStack {
                Color.black.opacity(0.18)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { dismissView() }

                VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("账号管理")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "#111827"))
                        Text("管理当前登录账号")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#6B7280"))
                    }
                    Spacer()
                    Button(action: { dismissView() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                HStack(spacing: 14) {
                    ZStack {
                        LinearGradient(
                            colors: [Color(hex: "#6750F5"), Color(hex: "#9277FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())

                        Image(systemName: "person.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("已登录")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#16A06A"))
                        Text(maskedPhone)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#111827"))
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#16A06A"))
                }
                .padding(.horizontal, 16)
                .frame(height: 82)
                .background(Color(hex: "#F7F5FF"))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#E8E2FF"), lineWidth: 1)
                )
                .padding(.top, 26)

                Spacer(minLength: 28)

                Button(action: { showSetPassword = true }) {
                    Text("设置密码")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#171A24"), Color(hex: "#35405A")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 16)

                Button(action: {
                    AppPreferences().logout()
                    isLoggedIn = false
                    NotificationCenter.default.post(name: .authStateDidChange, object: nil)
                }) {
                    Text("退出登录")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "#C2410C"))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color(hex: "#F0EAE4"))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#C2410C"), lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 10)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 28)
                .frame(maxWidth: isCompact ? proxy.size.width - 20 : min(proxy.size.width - 48, 520))
                .frame(height: dialogHeight)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 8)
                .padding(isCompact ? 8 : 24)
                .onTapGesture { }
            }
        }
    }

    private func dismissView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private var maskedPhone: String {
        let phone = AppPreferences().userPhone ?? ""
        guard phone.count >= 7 else { return phone }
        return String(phone.prefix(3)) + " **** " + String(phone.suffix(4))
    }
}

extension Notification.Name {
    static let authStateDidChange = Notification.Name("agentClaw.authStateDidChange")
}

struct SetPasswordView: View {
    let phone: String
    @Environment(\.presentationMode) private var presentationMode
    @State private var code = ""
    @State private var password = ""
    @State private var countdown = 0
    @State private var isSendingCode = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var countdownTimer: AnyCancellable?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("验证手机号后修改密码")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "#1A1A2E"))
                        Text("验证码将发送至 \(maskedPhone)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("验证码")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("请输入6位验证码", text: Binding(
                                get: { code },
                                set: { code = String($0.filter { $0.isNumber }.prefix(6)) }
                            ))
                            .keyboardType(.numberPad)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#1A1A2E"))
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
                        .background(Color(hex: "#F6F2FF"))
                        .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("新密码")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        SecureField("请输入至少6位新密码", text: $password)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#1A1A2E"))
                            .accentColor(Color(hex: "#6750F5"))
                            .environment(\.colorScheme, .light)
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(Color(hex: "#F6F2FF"))
                            .cornerRadius(12)
                    }

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#E5484D"))
                    }

                    Button(action: submit) {
                        ZStack {
                            if isSubmitting {
                                CompatProgressView()
                            } else {
                                Text("确认修改")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(canSubmit ? Color(hex: "#6750F5") : Color.gray.opacity(0.4))
                        .cornerRadius(14)
                    }
                    .disabled(!canSubmit)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitle(Text("修改密码"), displayMode: .inline)
            .navigationBarItems(leading: Button("取消") { presentationMode.wrappedValue.dismiss() })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert(isPresented: $showSuccess) {
            Alert(title: Text("修改成功"), message: Text("现在可以使用新密码登录。"), dismissButton: .default(Text("完成")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onDisappear { countdownTimer?.cancel() }
    }

    private var maskedPhone: String {
        guard phone.count >= 7 else { return phone }
        return String(phone.prefix(3)) + "****" + String(phone.suffix(4))
    }

    private var canSendCode: Bool {
        phone.count == 11 && countdown == 0 && !isSendingCode && !isSubmitting
    }

    private var canSubmit: Bool {
        code.count == 6 && password.count >= 6 && !isSubmitting
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

    private func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await AuthService.shared.setPassword(phone: phone, code: code, password: password)
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
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

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
