import SwiftUI

struct GatewaySettingsView: View {
    @ObservedObject var viewModel: GatewayConnectionViewModel

    var body: some View {
        Form {
            Section(header: Text("对话服务器接口")) {
                TextField("https://www.cjym123.cn/v1", text: $viewModel.gatewayURLText)
                    .font(.system(size: 12))
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                SecureField("Token", text: $viewModel.tokenText)
                    .font(.system(size: 12))

                Toggle(isOn: $viewModel.allowInsecureLocalNetwork) {
                    Text("允许 HTTP 接口")
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            Section {
                Button(action: viewModel.saveAndTest) {
                    HStack {
                        Text("保存接口地址")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer()
                        if case .checking = viewModel.status {
                            CompatProgressView()
                                .scaleEffect(0.82)
                        }
                    }
                }
                .disabled(isChecking)
            }

            Section(header: Text("状态")) {
                Text(viewModel.status.title)
                    .font(.system(size: 13, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if case .failed(let message) = viewModel.status {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.system(size: 12))
        .navigationBarTitle("服务器接口", displayMode: .inline)
    }

    private var isChecking: Bool {
        if case .checking = viewModel.status {
            return true
        }
        return false
    }
}
