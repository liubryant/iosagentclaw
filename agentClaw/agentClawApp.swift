

//
//  agentClawApp.swift
//  agentClaw
//
//  Created by Liuzheng on 2026/5/16.
//  Email: bryant_liu24@126.com
//

import SwiftUI
import UIKit

@main
struct agentClawApp {
    static func main() {
        if #available(iOS 14.0, *) {
            ModernApp.main()
        } else {
            UIApplicationMain(
                CommandLine.argc,
                CommandLine.unsafeArgv,
                nil,
                NSStringFromClass(AppDelegate.self)
            )
        }
    }
}

@available(iOS 14.0, *)
struct ModernApp: App {
    @UIApplicationDelegateAdaptor(QuickActionAppDelegate.self) private var quickActionDelegate
    private let container = DependencyContainer()

    init() {
        IAPBootstrap.startObservingTransactions()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                .onOpenURL { url in
                    QuickActionRouter.shared.route(url)
                }
        }
    }
}

enum AgentClawQuickAction: String {
    case chat = "com.agentclaw.quick.chat"
    case avatar = "com.agentclaw.quick.avatar"
    case image = "com.agentclaw.quick.image"
}

final class QuickActionRouter {
    static let shared = QuickActionRouter()
    private var pendingAction: AgentClawQuickAction?
    private let lock = NSLock()

    func route(_ shortcutItem: UIApplicationShortcutItem) {
        guard let action = AgentClawQuickAction(rawValue: shortcutItem.type) else { return }
        lock.lock()
        pendingAction = action
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .agentClawQuickAction, object: action)
        }
    }

    func route(_ url: URL) {
        guard url.scheme?.lowercased() == "agentclaw",
              url.host?.lowercased() == "quick",
              let action = AgentClawQuickAction(widgetPath: url.path) else { return }
        lock.lock()
        pendingAction = action
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .agentClawQuickAction, object: action)
        }
    }

    func consumePendingAction() -> AgentClawQuickAction? {
        lock.lock()
        defer { lock.unlock() }
        let action = pendingAction
        pendingAction = nil
        return action
    }
}

private extension AgentClawQuickAction {
    init?(widgetPath: String) {
        switch widgetPath.lowercased() {
        case "/chat": self = .chat
        case "/avatar": self = .avatar
        case "/image": self = .image
        default: return nil
        }
    }
}

extension Notification.Name {
    static let agentClawQuickAction = Notification.Name("agentClaw.quickAction")
}

final class QuickActionAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            QuickActionRouter.shared.route(item)
        }
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        QuickActionRouter.shared.route(shortcutItem)
        completionHandler(AgentClawQuickAction(rawValue: shortcutItem.type) != nil)
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let item = options.shortcutItem {
            QuickActionRouter.shared.route(item)
        }
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let item = connectionOptions.shortcutItem {
            QuickActionRouter.shared.route(item)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        QuickActionRouter.shared.route(shortcutItem)
        completionHandler(AgentClawQuickAction(rawValue: shortcutItem.type) != nil)
    }
}

/// 全局内购交易监听：处理支付成功但 App 中断(被杀/家长同意后到账)等未完成交易，
/// 下次启动时无论是否登录都补交后端校验并恢复会员；登录仅用于可选的账号同步。
enum IAPBootstrap {
    static func startObservingTransactions() {
        StoreKitService.shared.startObservingUpdates { signed in
            let prefs = AppPreferences()
            do {
                let verified = try await PaymentService.shared.verifyApplePurchase(
                    // 未登录时不能把游客权益凭证当成正式账号身份上报；Apple 原始交易号
                    // 本身即可稳定找回匿名会员，登录后才携带手机号账号 Token 做可选同步。
                    token: prefs.isLoggedIn ? prefs.userAccessToken : nil,
                    productId: "",
                    appleProductId: signed.productId,
                    transactionId: signed.transactionId,
                    jws: signed.jws
                )
                let status = verified.membership
                if let guestToken = verified.guestAccessToken { prefs.appleGuestAccessToken = guestToken }
                prefs.isVipActive = status.active
                prefs.vipExpiresAt = status.expiresAt
                prefs.appleVipActive = verified.appleActive
                prefs.appleVipExpiresAt = verified.appleExpiresAt
                QuotaManager.shared.applyServerQuota(status)
                await StoreKitService.shared.finish(transactionId: signed.transactionId)
            } catch {
                // 校验失败则不 finish，下次启动重试
            }
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private let container = DependencyContainer()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 合规初始化：仅在用户已同意隐私政策的情况下初始化SDK
        if container.preferences.onboardingCompleted {
            UMengAnalytics.shared.initialize()
            PangleAdManager.shared.initialize()
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(
            rootView: ContentView(container: container)
        )
        self.window = window
        window.makeKeyAndVisible()
        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            QuickActionRouter.shared.route(item)
        }
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        QuickActionRouter.shared.route(shortcutItem)
        completionHandler(AgentClawQuickAction(rawValue: shortcutItem.type) != nil)
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        QuickActionRouter.shared.route(url)
        return url.scheme?.lowercased() == "agentclaw"
    }
}
