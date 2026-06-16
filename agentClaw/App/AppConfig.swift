import Foundation

enum AppConfig {
    static let appName = "Agent"

    // 使用环境管理器获取默认网关 URL
    static var defaultGatewayURL: URL {
        return EnvironmentManager.shared.baseURL
    }

    static let defaultChatModel = "glm-4.7"
    static let requestTimeout: TimeInterval = 30
    static let documentGenerationRequestTimeout: TimeInterval = 10 * 60
    static let mediaGenerationRequestTimeout: TimeInterval = 30 * 60
}

// MARK: - Environment Manager

/// 环境类型
enum AppEnvironment {
    case production  // 生产环境
    case testing     // 测试环境

    var baseURL: String {
        switch self {
        case .production:
            return "https://www.cjym123.cn/v1"
        case .testing:
            #if DEBUG
            return "http://192.168.1.37:8066/v1"
            #else
            return "https://www.cjym123.cn/v1"  // Release版本使用生产环境
            #endif
        }
    }

    var displayName: String {
        switch self {
        case .production:
            return "生产环境"
        case .testing:
            return "测试环境"
        }
    }
}

/// 环境管理单例类
final class EnvironmentManager {
    static let shared = EnvironmentManager()

    // 私有化初始化方法，确保单例
    private init() {
        loadEnvironment()
    }

    // 当前环境，默认为生产环境
    private(set) var currentEnvironment: AppEnvironment = .production {
        didSet {
            saveEnvironment()
        }
    }

    // 获取当前环境的 Base URL
    var baseURL: URL {
        return URL(string: currentEnvironment.baseURL)!
    }

    // 切换环境
    func switchEnvironment(to environment: AppEnvironment) {
        currentEnvironment = environment
        NotificationCenter.default.post(name: .environmentDidChange, object: nil)
    }

    // 保存环境配置到 UserDefaults
    private func saveEnvironment() {
        let rawValue = currentEnvironment == .production ? "production" : "testing"
        UserDefaults.standard.set(rawValue, forKey: "app_environment")
    }

    // 从 UserDefaults 加载环境配置
    private func loadEnvironment() {
        let rawValue = UserDefaults.standard.string(forKey: "app_environment") ?? "production"
        currentEnvironment = rawValue == "testing" ? .testing : .production
    }
}

// 环境切换通知
extension Notification.Name {
    static let environmentDidChange = Notification.Name("environmentDidChange")
}
