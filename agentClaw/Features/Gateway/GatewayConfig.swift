import Foundation

struct GatewayConfig: Equatable {
    var baseURL: URL
    var token: String?
    var allowInsecureLocalNetwork: Bool
}

enum GatewayTokenKey {
    static let gatewayToken = "gateway_token"
}

