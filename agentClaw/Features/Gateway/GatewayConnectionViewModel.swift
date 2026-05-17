import Combine
import Foundation

final class GatewayConnectionViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case connected
        case failed(String)

        var title: String {
            switch self {
            case .idle:
                return "未连接"
            case .checking:
                return "连接中"
            case .connected:
                return "已连接"
            case .failed:
                return "连接失败"
            }
        }
    }

    @Published var gatewayURLText: String
    @Published var tokenText: String
    @Published var allowInsecureLocalNetwork: Bool
    @Published private(set) var status: Status = .idle

    private let gatewayClient: GatewayClient

    init(gatewayClient: GatewayClient) {
        self.gatewayClient = gatewayClient
        let config = gatewayClient.config
        gatewayURLText = config.baseURL.absoluteString
        tokenText = config.token ?? ""
        allowInsecureLocalNetwork = config.allowInsecureLocalNetwork
    }

    func saveAndTest() {
        status = .checking
        do {
            try gatewayClient.saveConfig(buildConfig())
        } catch {
            status = .failed(error.localizedDescription)
            return
        }

        gatewayClient.healthCheck { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.status = .connected
                case .failure(let error):
                    self?.status = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func buildConfig() throws -> GatewayConfig {
        guard let url = URL(string: gatewayURLText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw GatewayConfigError.invalidURL
        }
        return GatewayConfig(
            baseURL: url,
            token: tokenText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            allowInsecureLocalNetwork: allowInsecureLocalNetwork
        )
    }
}

enum GatewayConfigError: Error, LocalizedError {
    case invalidURL

    var errorDescription: String? {
        "Gateway 地址无效"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
