import SwiftUI

struct OnboardingView: View {
    var onContinue: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showDisagreeAlert = false
    @State private var showGoodbyeScreen = false

    var body: some View {
        ZStack {
            // 主隐私政策界面
            GeometryReader { geometry in
                let isCompact = horizontalSizeClass == .compact || geometry.size.width < 560

                ZStack {
                    Color.black.opacity(0.3).edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    Spacer(minLength: isCompact ? 40 : 80)

                    VStack(spacing: 24) {
                        // Logo 和标题
                        VStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.93, blue: 0.86))
                                    .frame(width: 100, height: 80)

                                Text("🦞")
                                    .font(.system(size: 48))
                            }

                            VStack(spacing: 8) {
                                Text("欢迎使用 AgentClaw")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.black)

                                Text("您的智能 AI 助手")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                        }

                        // 介绍内容
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AgentClaw 是一款强大的 AI 智能助手，为您提供智能对话、任务处理和多种实用技能。我们致力于保护您的隐私和数据安全。")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.035))
                        .cornerRadius(12)

                        // 协议说明
                        VStack(spacing: 10) {
                            HStack(spacing: 4) {
                                Text("继续使用即表示您同意")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 8) {
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
                                    .foregroundColor(.secondary)

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
                        }

                        // 按钮区域
                        HStack(spacing: 12) {
                            Button(action: {
                                // 显示提示对话框，告知用户必须同意才能使用
                                showDisagreeAlert = true
                            }) {
                                Text("不同意")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.black.opacity(0.06))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                // 用户同意隐私政策后，初始化友盟统计（合规要求）
                                UMengAnalytics.shared.initialize()
                                // 继续进入应用
                                onContinue()
                            }) {
                                Text("同意并继续")
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
                    .padding(.horizontal, 28)
                    .padding(.vertical, 36)
                    .frame(maxWidth: isCompact ? geometry.size.width - 40 : 480)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)

                    Spacer(minLength: isCompact ? 40 : 80)
                }
                .padding(.horizontal, 20)
            }
        }
        .alert(isPresented: $showDisagreeAlert) {
            Alert(
                title: Text("温馨提示"),
                message: Text("如果您不同意《用户协议》和《隐私政策》，很遗憾我们将无法为您提供服务。"),
                primaryButton: .default(Text("同意并继续")) {
                    // 用户在二次确认中选择同意
                    UMengAnalytics.shared.initialize()
                    onContinue()
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
