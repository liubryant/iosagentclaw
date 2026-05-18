

//
//  agentClawApp.swift
//  agentClaw
//
//  Created by MAC on 2026/5/16.
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
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(
            rootView: ContentView(container: container)
        )
        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}
