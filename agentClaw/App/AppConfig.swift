import Foundation

enum AppConfig {
    static let appName = "AgentClaw"
    static let defaultGatewayURL = URL(string: "http://39.108.144.196:8066/v1")!
    static let defaultChatModel = "glm-4.7"
    static let requestTimeout: TimeInterval = 30
    static let mediaGenerationRequestTimeout: TimeInterval = 30 * 60
}
