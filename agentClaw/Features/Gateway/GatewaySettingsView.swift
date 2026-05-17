import SwiftUI

struct GatewaySettingsView: View {
    @ObservedObject var viewModel: GatewayConnectionViewModel

    var body: some View {
        Form {
            Section(header: Text("对话服务器接口")) {
                TextField("http://39.108.144.196:8066/v1", text: $viewModel.gatewayURLText)
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
                            ProgressView()
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
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.system(size: 12))
        .navigationTitle("服务器接口")
    }

    private var isChecking: Bool {
        if case .checking = viewModel.status {
            return true
        }
        return false
    }
}
