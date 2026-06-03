

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
    private let container = DependencyContainer()

    init() {
        // 合规初始化：仅在用户已同意隐私政策的情况下初始化SDK
        if container.preferences.onboardingCompleted {
            UMengAnalytics.shared.initialize()
            PangleAdManager.shared.initialize()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
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
        return true
    }
}
