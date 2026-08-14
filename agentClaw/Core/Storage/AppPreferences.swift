import Foundation

final class AppPreferences {
    private enum Key {
        static let gatewayURL = "gateway_url"
        static let allowInsecureLocalNetwork = "allow_insecure_local_network"
        static let onboardingCompleted = "onboarding_completed"
        static let aiDataSharingConsentVersion = "ai_data_sharing_consent_version"
        static let chatHistorySnapshot = "chat_history_snapshot"
        static let avatarConversationHistory = "avatar_conversation_history"
        // Auth
        static let isLoggedIn = "is_logged_in"
        static let userPhone = "user_phone"
        // VIP
        static let isVipActive = "vip_active"
        static let vipExpiresAt = "vip_expires_at"
        // Server quota config
        static let serverFreeVideoDaily = "server_free_video_daily"
        static let serverFreeImageDaily = "server_free_image_daily"
        static let serverVipVideoDaily = "server_vip_video_daily"
        static let serverVipImageDaily = "server_vip_image_daily"
        static let serverVipRemindDays = "server_vip_remind_days"
        // Quota usage
        static let quotaVideoDate = "quota_video_date"
        static let quotaVideoCount = "quota_video_count"
        static let quotaImageDate = "quota_image_date"
        static let quotaImageCount = "quota_image_count"
        static let avatarFreeConversationCount = "avatar_free_conversation_count"
    }

    private static let keychainTokenAccount = "user_access_token"

    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
    }

    // MARK: - Gateway (existing)

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

    /// Versioned separately from the general privacy-policy consent because Apple
    /// requires explicit permission before sharing user content with a third-party AI.
    private static let currentAIDataSharingConsentVersion = 1

    var hasAIDataSharingConsent: Bool {
        defaults.integer(forKey: Key.aiDataSharingConsentVersion)
            >= Self.currentAIDataSharingConsentVersion
    }

    func grantAIDataSharingConsent() {
        defaults.set(
            Self.currentAIDataSharingConsentVersion,
            forKey: Key.aiDataSharingConsentVersion
        )
    }

    func revokeAIDataSharingConsent() {
        defaults.removeObject(forKey: Key.aiDataSharingConsentVersion)
    }

    var chatHistorySnapshot: ChatHistorySnapshot? {
        get {
            guard let data = defaults.data(forKey: Key.chatHistorySnapshot) else { return nil }
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

    var avatarConversationHistory: [AvatarConversationTurn] {
        get {
            guard let data = defaults.data(forKey: Key.avatarConversationHistory) else { return [] }
            return (try? decoder.decode([AvatarConversationTurn].self, from: data)) ?? []
        }
        set {
            let retained = Array(newValue.suffix(100))
            if let data = try? encoder.encode(retained) {
                defaults.set(data, forKey: Key.avatarConversationHistory)
            }
        }
    }

    var avatarFreeConversationCount: Int {
        get { defaults.integer(forKey: Key.avatarFreeConversationCount) }
        set { defaults.set(max(0, newValue), forKey: Key.avatarFreeConversationCount) }
    }

    // MARK: - Auth

    var isLoggedIn: Bool {
        get { defaults.bool(forKey: Key.isLoggedIn) }
        set { defaults.set(newValue, forKey: Key.isLoggedIn) }
    }

    var userPhone: String? {
        get { defaults.string(forKey: Key.userPhone) }
        set { defaults.set(newValue, forKey: Key.userPhone) }
    }

    var userAccessToken: String? {
        get { keychain.string(for: Self.keychainTokenAccount) }
        set { try? keychain.setString(newValue, for: Self.keychainTokenAccount) }
    }

    func logout() {
        isLoggedIn = false
        userPhone = nil
        userAccessToken = nil
        isVipActive = false
        vipExpiresAt = nil
    }

    // MARK: - VIP

    var isVipActive: Bool {
        get { defaults.bool(forKey: Key.isVipActive) }
        set { defaults.set(newValue, forKey: Key.isVipActive) }
    }

    var vipExpiresAt: String? {
        get { defaults.string(forKey: Key.vipExpiresAt) }
        set { defaults.set(newValue, forKey: Key.vipExpiresAt) }
    }

    // MARK: - Server Quota Config (refreshed from /membership)

    var serverFreeVideoDaily: Int {
        get { defaults.object(forKey: Key.serverFreeVideoDaily) as? Int ?? -1 }
        set { defaults.set(newValue, forKey: Key.serverFreeVideoDaily) }
    }

    var serverFreeImageDaily: Int {
        get { defaults.object(forKey: Key.serverFreeImageDaily) as? Int ?? -1 }
        set { defaults.set(newValue, forKey: Key.serverFreeImageDaily) }
    }

    var serverVipVideoDaily: Int {
        get { defaults.object(forKey: Key.serverVipVideoDaily) as? Int ?? -1 }
        set { defaults.set(newValue, forKey: Key.serverVipVideoDaily) }
    }

    var serverVipImageDaily: Int {
        get { defaults.object(forKey: Key.serverVipImageDaily) as? Int ?? -1 }
        set { defaults.set(newValue, forKey: Key.serverVipImageDaily) }
    }

    var serverVipRemindDays: Int {
        get { defaults.object(forKey: Key.serverVipRemindDays) as? Int ?? 3 }
        set { defaults.set(newValue, forKey: Key.serverVipRemindDays) }
    }

    // MARK: - Quota Usage

    var quotaVideoDate: String {
        get { defaults.string(forKey: Key.quotaVideoDate) ?? "" }
        set { defaults.set(newValue, forKey: Key.quotaVideoDate) }
    }

    var quotaVideoCount: Int {
        get { defaults.integer(forKey: Key.quotaVideoCount) }
        set { defaults.set(newValue, forKey: Key.quotaVideoCount) }
    }

    var quotaImageDate: String {
        get { defaults.string(forKey: Key.quotaImageDate) ?? "" }
        set { defaults.set(newValue, forKey: Key.quotaImageDate) }
    }

    var quotaImageCount: Int {
        get { defaults.integer(forKey: Key.quotaImageCount) }
        set { defaults.set(newValue, forKey: Key.quotaImageCount) }
    }
}
