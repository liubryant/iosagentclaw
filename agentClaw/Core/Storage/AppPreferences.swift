import Foundation

final class AppPreferences {
    private enum Key {
        static let gatewayURL = "gateway_url"
        static let allowInsecureLocalNetwork = "allow_insecure_local_network"
        static let onboardingCompleted = "onboarding_completed"
        static let chatHistorySnapshot = "chat_history_snapshot"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var gatewayURL: URL {
        get {
            guard
                let raw = defaults.string(forKey: Key.gatewayURL),
                let url = URL(string: raw)
            else {
                return AppConfig.defaultGatewayURL
            }
            if raw == "http://127.0.0.1:18789" {
                return AppConfig.defaultGatewayURL
            }
            return url
        }
        set {
            defaults.set(newValue.absoluteString, forKey: Key.gatewayURL)
        }
    }

    var allowInsecureLocalNetwork: Bool {
        get { defaults.object(forKey: Key.allowInsecureLocalNetwork) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.allowInsecureLocalNetwork) }
    }

    var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Key.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Key.onboardingCompleted) }
    }

    var chatHistorySnapshot: ChatHistorySnapshot? {
        get {
            guard let data = defaults.data(forKey: Key.chatHistorySnapshot) else {
                return nil
            }
            return try? decoder.decode(ChatHistorySnapshot.self, from: data)
        }
        set {
            guard let snapshot = newValue else {
                defaults.removeObject(forKey: Key.chatHistorySnapshot)
                defaults.synchronize()
                return
            }
            if let data = try? encoder.encode(snapshot) {
                defaults.set(data, forKey: Key.chatHistorySnapshot)
                defaults.synchronize()
            }
        }
    }
}
