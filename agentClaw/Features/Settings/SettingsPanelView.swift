import SwiftUI

struct SettingsPanelView: View {
    enum Page {
        case skills
        case about
    }

    @ObservedObject var gatewayViewModel: GatewayConnectionViewModel
    @ObservedObject var chatViewModel: ChatViewModel
    @Binding var isPresented: Bool
    @State private var selectedPage: Page = .skills
    @State private var showEnvironmentAlert = false
    @State private var showClearDataAlert = false
    @State private var currentEnvironment: AppEnvironment = .production
    @State private var tapCount = 0
    @State private var lastTapTime = Date()
    @State private var showEnvironmentOption = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let skills = [
        SkillItem(name: "PDF", detail: "PDF 表单识别、图片转换、字段提取", enabled: true),
        SkillItem(name: "PPTX", detail: "演示文稿生成、页面编辑、缩略图", enabled: true),
        SkillItem(name: "HTML Default", detail: "Markdown 到 HTML 的基础转换", enabled: true),
        SkillItem(name: "Multi Search Engine", detail: "多搜索源查询与整理", enabled: false)
    ]

    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "V\(version)"
        }
        return "V1.0.0"
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

                settingsPanel(isCompact: isCompact)
                    .padding(10)
                    .frame(maxWidth: isCompact ? proxy.size.width - 20 : proxy.size.width - 48)
                    .frame(height: max(dialogHeight, isCompact ? 320 : 420))
                    .background(settingLeftBackground)
                    .cornerRadius(14)
                    .padding(isCompact ? 8 : 24)
            }
        }
        .onAppear {
            currentEnvironment = EnvironmentManager.shared.currentEnvironment
        }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image("slide_setting")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text("设置")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 40)

            menuButton(page: .skills, imageName: "list_skill", title: "技能管理")
            menuButton(page: .about, imageName: "list_about", title: "关于我们")

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(settingLeftBackground)
    }

    @ViewBuilder
    private func settingsPanel(isCompact: Bool) -> some View {
        if isCompact {
            VStack(spacing: 0) {
                compactHeader
                    .padding(.bottom, 8)

                HStack(spacing: 6) {
                    menuButton(page: .skills, imageName: "list_skill", title: "技能")
                    menuButton(page: .about, imageName: "list_about", title: "关于")
                }
                .padding(.bottom, 8)

                content(isCompact: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            HStack(spacing: 10) {
                menu
                    .frame(width: 200)

                content(isCompact: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var compactHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image("slide_setting")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("设置")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
            }
            Spacer()
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func content(isCompact: Bool) -> some View {
        Group {
            switch selectedPage {
            case .skills:
                skillsPage
            case .about:
                aboutPage
            }
        }
        .padding(isCompact ? 12 : 20)
        .background(settingRightBackground)
        .cornerRadius(12)
    }

    private var skillsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            pageHeader(title: "技能管理", subtitle: "扩展智能体的能力：一键集成精选技能与工具")

            ScrollView {
                skillGrid
                    .padding(.bottom, 4)
            }
        }
    }

    private var skillGrid: some View {
        VStack(spacing: 10) {
            ForEach(skillRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 10) {
                    ForEach(skillRows[rowIndex]) { skill in
                        skillCard(skill)
                    }

                    if skillRows[rowIndex].count == 1 {
                        Spacer()
                    }
                }
            }
        }
    }

    private var aboutPage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 4) {
                        Image("app_icon_display")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 59, height: 59)
                            .onTapGesture {
                                handleLogoTap()
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    VStack(spacing: 8) {
                        versionInfoRow(title: "当前版本", detail: appVersion)
                        if showEnvironmentOption {
                            environmentSwitchRow()
                        }
                        aboutListRow(title: "用户协议", detail: nil, url: "https://www.cjym123.cn/agreement_agentclaw.html")
                        aboutListRow(title: "隐私政策", detail: nil, url: "https://www.cjym123.cn/privacy_agentclaw.html")

                        clearDataButton()
                    }
                    .padding(.top, 4)
                }
            }

            icpFilingRow()
                .padding(.top, 30)
                .padding(.bottom, 16)
        }
    }

    private var skillRows: [[SkillItem]] {
        stride(from: 0, to: skills.count, by: 2).map { index in
            Array(skills[index..<min(index + 2, skills.count)])
        }
    }

    private func menuButton(page: Page, imageName: String, title: String) -> some View {
        Button(action: { selectedPage = page }) {
            HStack(spacing: 10) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.system(size: 12, weight: selectedPage == page ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer()
            }
            .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(selectedPage == page ? Color.white.opacity(0.72) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func pageHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                .lineLimit(2)
                .minimumScaleFactor(0.88)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(AgentClawDesign.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func skillCard(_ skill: SkillItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image("icon_skill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 23, height: 30)

                Text(skill.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                    .lineLimit(1)

                Spacer()

                Image("icon_remove")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }

            Text(skill.detail)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.40, green: 0.40, blue: 0.40))
                .lineLimit(2)
                .padding(.leading, 33)

            Divider().background(Color(red: 0.93, green: 0.93, blue: 0.93))

            HStack {
                Text("内置技能")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color(red: 0.95, green: 0.96, blue: 0.98))
                    .cornerRadius(6)
                Spacer()
                Image(skill.enabled ? "switch_on" : "switch_off")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 14)
            }
        }
        .padding(14)
        .frame(minHeight: 130, alignment: .topLeading)
        .background(Color.white)
        .cornerRadius(12)
    }

    private func versionInfoRow(title: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Color.white)
        .cornerRadius(8)
    }

    private func aboutListRow(title: String, detail: String? = nil, url: String? = nil) -> some View {
        Button(action: {
            if let urlString = url, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                }
                Spacer()
                if detail == nil && url != nil {
                    Image("arrow_right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color.white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func clearDataButton() -> some View {
        Button(action: {
            showClearDataAlert = true
        }) {
            HStack {
                Text("清除所有数据")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                Spacer()
                Image("arrow_right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color.white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .alert(isPresented: $showClearDataAlert) {
            Alert(
                title: Text("清除所有数据"),
                message: Text("此操作将清除所有聊天记录、网关配置等数据，且无法恢复。确定要继续吗？"),
                primaryButton: .destructive(Text("清除")) {
                    clearAllData()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private func environmentSwitchRow() -> some View {
        Button(action: {
            showEnvironmentAlert = true
        }) {
            HStack {
                Text("运行环境")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                Spacer()
                Text(currentEnvironment.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.40, green: 0.40, blue: 0.40))
                Image("arrow_right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color.white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .alert(isPresented: $showEnvironmentAlert) {
            Alert(
                title: Text("选择运行环境"),
                message: Text("切换环境后将使用对应的服务器地址"),
                primaryButton: .default(Text("生产环境")) {
                    switchToEnvironment(.production)
                },
                secondaryButton: .default(Text("测试环境")) {
                    switchToEnvironment(.testing)
                }
            )
        }
    }

    private func switchToEnvironment(_ environment: AppEnvironment) {
        currentEnvironment = environment
        EnvironmentManager.shared.switchEnvironment(to: environment)
        // 更新网关配置
        gatewayViewModel.refreshFromEnvironment()
    }

    private func handleLogoTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)

        // 如果距离上次点击超过0.5秒，重置计数
        if timeSinceLastTap > 0.5 {
            tapCount = 1
        } else {
            tapCount += 1
        }

        lastTapTime = now

        // 当点击6次时，切换显示状态
        if tapCount >= 6 {
            withAnimation(.easeInOut(duration: 0.3)) {
                showEnvironmentOption.toggle()
            }
            tapCount = 0
        }
    }

    private func clearAllData() {
        // 清除聊天历史（包括内存中的数据）
        chatViewModel.clearAllData()

        // 清除网关token
        let keychain = KeychainStore()
        try? keychain.setString(nil, for: GatewayTokenKey.gatewayToken)

        // 通知用户数据已清除
        showClearDataAlert = false

        // 刷新网关视图状态
        gatewayViewModel.refreshFromEnvironment()
    }

    private func icpFilingRow() -> some View {
        HStack(spacing: 0) {
            Spacer()

            Text("ICP备案号：")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))

            Button(action: {
                if let url = URL(string: "https://beian.miit.gov.cn/") {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("粤ICP备2024188934号-3A")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    .underline()
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
    }

    private var settingLeftBackground: Color {
        Color(red: 0.96, green: 0.97, blue: 0.98)
    }

    private var settingRightBackground: Color {
        Color(red: 0.98, green: 0.985, blue: 0.99)
    }
}

private struct SkillItem: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let enabled: Bool
}
