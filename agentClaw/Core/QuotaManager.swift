import Foundation

final class QuotaManager {
    static let shared = QuotaManager()

    private static let freeVideoDefault = 1
    private static let freeImageDefault = 3
    private static let vipVideoDefault = 5
    private static let vipImageDefault = 50

    private var prefs: AppPreferences { AppPreferences() }

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: Date())
    }

    // MARK: - Limits

    func freeVideoLimit() -> Int {
        let v = AppPreferences().serverFreeVideoDaily
        return v >= 0 ? v : Self.freeVideoDefault
    }

    func freeImageLimit() -> Int {
        let v = AppPreferences().serverFreeImageDaily
        return v >= 0 ? v : Self.freeImageDefault
    }

    func vipVideoLimit() -> Int {
        let v = AppPreferences().serverVipVideoDaily
        return v >= 0 ? v : Self.vipVideoDefault
    }

    func vipImageLimit() -> Int {
        let v = AppPreferences().serverVipImageDaily
        return v >= 0 ? v : Self.vipImageDefault
    }

    func videoLimit() -> Int {
        let preferences = AppPreferences()
        return preferences.isLoggedIn && preferences.isVipActive ? vipVideoLimit() : freeVideoLimit()
    }

    func imageLimit() -> Int {
        let preferences = AppPreferences()
        return preferences.isLoggedIn && preferences.isVipActive ? vipImageLimit() : freeImageLimit()
    }

    // MARK: - Today Usage

    func todayVideoCount() -> Int {
        let p = AppPreferences()
        return p.quotaVideoDate == today ? p.quotaVideoCount : 0
    }

    func todayImageCount() -> Int {
        let p = AppPreferences()
        return p.quotaImageDate == today ? p.quotaImageCount : 0
    }

    // MARK: - Check

    func canGenerateVideo() -> Bool {
        todayVideoCount() < videoLimit()
    }

    func canGenerateImage() -> Bool {
        todayImageCount() < imageLimit()
    }

    // MARK: - Consume

    func consumeVideo() {
        let p = AppPreferences()
        let t = today
        let count = p.quotaVideoDate == t ? p.quotaVideoCount : 0
        p.quotaVideoDate = t
        p.quotaVideoCount = count + 1
    }

    func consumeImage() {
        let p = AppPreferences()
        let t = today
        let count = p.quotaImageDate == t ? p.quotaImageCount : 0
        p.quotaImageDate = t
        p.quotaImageCount = count + 1
    }

    // MARK: - Apply server config

    func applyServerQuota(_ status: MembershipStatus) {
        let p = AppPreferences()
        if let v = status.freeVideoDaily { p.serverFreeVideoDaily = v }
        if let v = status.freeImageDaily { p.serverFreeImageDaily = v }
        if let v = status.vipVideoDaily  { p.serverVipVideoDaily = v }
        if let v = status.vipImageDaily  { p.serverVipImageDaily = v }
        if let v = status.vipRemindDays  { p.serverVipRemindDays = v }
    }

    func refreshServerQuota() async {
        do {
            let preferences = AppPreferences()
            let status: MembershipStatus
            if preferences.isLoggedIn, let token = preferences.userAccessToken, !token.isEmpty {
                status = try await PaymentService.shared.loadMembership(token: token)
            } else {
                status = try await PaymentService.shared.loadPublicMembership()
            }
            applyServerQuota(status)
            #if DEBUG
            print("duix quota config_refreshed freeImage=\(freeImageLimit()) freeVideo=\(freeVideoLimit()) vipImage=\(vipImageLimit()) vipVideo=\(vipVideoLimit())")
            #endif
        } catch {
            #if DEBUG
            print("duix quota config_refresh_failed error=\(error.localizedDescription) fallbackImage=\(freeImageLimit()) fallbackVideo=\(freeVideoLimit())")
            #endif
        }
    }
}
