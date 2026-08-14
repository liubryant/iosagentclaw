import SwiftUI

struct OnboardingView: View {
    var onContinue: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showDisagreeAlert = false
    @State private var showGoodbyeScreen = false

    private let dialogBackground = Color(hex: "#FFFFFF")
    private let titleText = Color(hex: "#16171D")
    private let bodyText = Color(hex: "#4C4F59")
    private let secondaryBodyText = Color(hex: "#626672")
    private let mutedSurface = Color(hex: "#F4F5F8")

    var body: some View {
        ZStack {
            // 主隐私政策界面
            GeometryReader { geometry in
                let isCompact = horizontalSizeClass == .compact || geometry.size.width < 560

	                ZStack {
	                    Color.black.opacity(0.3).edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    Spacer(minLength: isCompact ? 24 : 48)

                    VStack(spacing: 16) {
                        // Logo 和标题
                        VStack(spacing: 10) {
                            Image("app_icon_display")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

	                            Text("个人信息保护提示")
	                                .font(.system(size: 20, weight: .bold))
	                                .foregroundColor(titleText)
                        }

                        // 介绍内容
                        ScrollView(showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 12) {
	                                Text("欢迎来到Agent智能体生活助手！")
	                                    .font(.system(size: 14, weight: .semibold))
	                                    .foregroundColor(titleText)

                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("AI 模型服务由智谱大模型提供。我们倡导用户遵守相关法律法规及政策，不得使用本服务从事违法违规活动。")
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text("模型名称：智谱大模型 GLM-4.5")
                                        Text("授权模型：GLM-4.5")
                                        Text("授权编号：202606091295564742")
                                    }
                                    .font(.system(size: 13))
                                    .foregroundColor(bodyText)
                                    .lineSpacing(4)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 0) {
	                                        Text("我们将通过")
	                                            .font(.system(size: 13))
	                                            .foregroundColor(bodyText)

                                        Button(action: {
                                            if let url = URL(string: "https://www.cjym123.cn/agreement_agentclaw.html") {
                                                UIApplication.shared.open(url)
                                            }
                                        }) {
                                            Text("《用户协议》")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(AgentClawDesign.accent)
                                        }
                                        .buttonStyle(PlainButtonStyle())

	                                        Text("和")
	                                            .font(.system(size: 13))
	                                            .foregroundColor(bodyText)

                                        Button(action: {
                                            if let url = URL(string: "https://www.cjym123.cn/privacy_agentclaw.html") {
                                                UIApplication.shared.open(url)
                                            }
                                        }) {
                                            Text("《隐私政策》")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(AgentClawDesign.accent)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }

	                                    Text("帮助您了解我们为您提供的服务、我们如何处理个人信息以及您享有的权利。我们会严格按照相关法律法规要求，采取各种安全措施来保护您的个人信息。")
	                                        .font(.system(size: 13))
	                                        .foregroundColor(bodyText)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

	                                Text("点击\"同意\"按钮，表示您已知情并同意以上协议和以下约定。")
	                                    .font(.system(size: 13))
	                                    .foregroundColor(bodyText)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1.   为了保障软件的安全运行和账户安全，我们会申请收集您的设备信息、IP地址、MAC地址。")
                                    Text("2.   保存图片、视频，需要使用您的存储、相机、麦克风权限。")
                                    Text("3.   我们可能会申请位置权限，用于为您推荐您可能感兴趣的内容。")
                                    Text("4.   我们尊重您的选择权，您可以删除您的个人数据并管理，我们也为您提供反馈投诉渠道。")
	                                }
	                                .font(.system(size: 13))
	                                .foregroundColor(bodyText)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                        }
	                        .frame(maxWidth: .infinity, alignment: .leading)
	                        .frame(maxHeight: isCompact ? 220 : 300)
	                        .background(mutedSurface)
	                        .cornerRadius(12)

                        // 按钮区域
                        HStack(spacing: 12) {
                            Button(action: {
                                // 显示提示对话框，告知用户必须同意才能使用
                                showDisagreeAlert = true
                            }) {
	                                Text("不同意")
	                                    .font(.system(size: 15, weight: .medium))
	                                    .foregroundColor(secondaryBodyText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
	                                    .background(Color(hex: "#ECEEF3"))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                // 用户同意隐私政策后，先请求 ATT 权限，再初始化友盟统计（合规要求）
                                TrackingAuthorization.requestIfNeeded {
                                    UMengAnalytics.shared.initialize()
                                    // 继续进入应用
                                    onContinue()
                                }
                            }) {
                                Text("同意")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(AgentClawDesign.accent)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
	                    .padding(.horizontal, 24)
	                    .padding(.vertical, 24)
	                    .frame(maxWidth: isCompact ? geometry.size.width - 40 : min(geometry.size.width - 96, 560))
	                    .background(dialogBackground)
	                    .cornerRadius(16)
	                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
	                    .environment(\.colorScheme, .light)

                    Spacer(minLength: isCompact ? 24 : 48)
                }
                .padding(.horizontal, 20)
            }
        }
        .alert(isPresented: $showDisagreeAlert) {
            Alert(
                title: Text("温馨提示"),
                message: Text("如果您不同意《用户协议》和《隐私政策》，很遗憾我们将无法为您提供服务。"),
                primaryButton: .default(Text("同意")) {
                    // 用户在二次确认中选择同意：先请求 ATT 权限，再初始化友盟统计
                    TrackingAuthorization.requestIfNeeded {
                        UMengAnalytics.shared.initialize()
                        onContinue()
                    }
                },
                secondaryButton: .destructive(Text("放弃使用")) {
                    // 显示告别界面，然后温和退出
                    showGoodbyeScreen = true
                    // 延迟2秒后退出，给用户一个过渡
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        exit(0)
                    }
                }
            )
        }

            // 告别界面
            if showGoodbyeScreen {
                ZStack {
                    Color.black.opacity(0.9).edgesIgnoringSafeArea(.all)

                    VStack(spacing: 24) {
                        Text("👋")
                            .font(.system(size: 72))

                        VStack(spacing: 12) {
                            Text("感谢您的访问")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)

                            Text("期待下次与您相见")
                                .font(.system(size: 16))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showGoodbyeScreen)
            }
        }
    }
}
