import SwiftUI

struct OnboardingView: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                VStack(spacing: 22) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 1.0, green: 0.93, blue: 0.86))
                            .frame(width: 96, height: 76)

                        Text("🦞")
                            .font(.system(size: 42))
                    }

                    VStack(spacing: 10) {
                        Text("AgentClaw 正在准备")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)

                        Text("iOS 版本使用公网对话服务器接口，不再在本机启动 Linux/proot。")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    ProgressView(value: 1.0)
                        .accentColor(AgentClawDesign.accent)
                        .frame(maxWidth: 220)

                    VStack(spacing: 10) {
                        StartupStepRow(title: "连接对话接口", detail: "39.108.144.196:8066/v1", isDone: true)
                        StartupStepRow(title: "初始化聊天工作台", detail: "会话、侧边栏、输入区", isDone: true)
                        StartupStepRow(title: "设备能力桥接", detail: "后续接入 iOS 能力子集", isDone: false)
                    }
                    .padding(.top, 4)

                    Button(action: onContinue) {
                        Text("进入 AgentClaw")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AgentClawDesign.accent)
                            .cornerRadius(8)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 32)
                .frame(maxWidth: 430)
                .background(Color.white)
                .cornerRadius(14)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct StartupStepRow: View {
    let title: String
    let detail: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "clock")
                .foregroundColor(isDone ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color.black.opacity(0.035))
        .cornerRadius(8)
    }
}

