//
//  SPLASH_AD_EXAMPLE.swift
//  agentClaw
//
//  开屏广告使用示例代码
//  Created by Claude on 2026/5/23.
//

import SwiftUI
import UIKit

// MARK: - 示例1: 在iOS 14+ SwiftUI应用中使用

@available(iOS 14.0, *)
struct ExampleApp: App {
    private let container = DependencyContainer()
    @Environment(\.scenePhase) private var scenePhase

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
                .onAppear {
                    // 应用启动后展示开屏广告
                    showSplashAdIfNeeded()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // 可选：应用从后台返回时也展示开屏广告
                // showSplashAdIfNeeded()
            }
        }
    }

    private func showSplashAdIfNeeded() {
        // 仅在用户已同意隐私政策后展示
        guard container.preferences.onboardingCompleted else {
            print("⚠️ 用户未同意隐私政策，跳过开屏广告")
            return
        }

        // 检查SDK是否已初始化
        guard PangleAdManager.shared.isSDKInitialized() else {
            print("⚠️ SDK未初始化，跳过开屏广告")
            return
        }

        // 延迟0.2秒，确保UI已完全加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            PangleSplashAdManager.shared.loadAndShowSplashAd(
                slotID: "104085288",
                tolerateTimeout: 3.0
            ) { success, error in
                if success {
                    print("✅ 开屏广告展示完成")
                } else if let error = error {
                    print("❌ 开屏广告展示失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - 示例2: 在iOS 13 UIKit应用中使用

class ExampleAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private let container = DependencyContainer()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 1. 初始化SDK（仅在用户同意隐私政策后）
        if container.preferences.onboardingCompleted {
            UMengAnalytics.shared.initialize()
            PangleAdManager.shared.initialize()
        }

        // 2. 设置主窗口
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(
            rootView: ContentView(container: container)
        )
        self.window = window
        window.makeKeyAndVisible()

        // 3. 展示开屏广告
        showSplashAdIfNeeded()

        return true
    }

    private func showSplashAdIfNeeded() {
        // 仅在用户已同意隐私政策后展示
        guard container.preferences.onboardingCompleted else {
            print("⚠️ 用户未同意隐私政策，跳过开屏广告")
            return
        }

        // 检查SDK是否已初始化
        guard PangleAdManager.shared.isSDKInitialized() else {
            print("⚠️ SDK未初始化，跳过开屏广告")
            return
        }

        // 延迟0.2秒，确保window已完全显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            PangleSplashAdManager.shared.loadAndShowSplashAd(
                slotID: "104085288",
                tolerateTimeout: 3.0
            ) { success, error in
                if success {
                    print("✅ 开屏广告展示完成")
                } else if let error = error {
                    print("❌ 开屏广告展示失败: \(error.localizedDescription)")
                }
            }
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // 可选：应用从后台返回时展示开屏广告
        // showSplashAdIfNeeded()
    }
}

// MARK: - 示例3: 在SceneDelegate中使用（iOS 13+）

@available(iOS 13.0, *)
class ExampleSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // 1. 设置主窗口
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(
            rootView: ContentView(container: DependencyContainer())
        )
        self.window = window
        window.makeKeyAndVisible()

        // 2. 展示开屏广告
        showSplashAdIfNeeded()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // 可选：Scene激活时展示开屏广告
        // showSplashAdIfNeeded()
    }

    private func showSplashAdIfNeeded() {
        // 仅在用户已同意隐私政策后展示
        let onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")
        guard onboardingCompleted else {
            print("⚠️ 用户未同意隐私政策，跳过开屏广告")
            return
        }

        // 检查SDK是否已初始化
        guard PangleAdManager.shared.isSDKInitialized() else {
            print("⚠️ SDK未初始化，跳过开屏广告")
            return
        }

        // 延迟0.2秒，确保window已完全显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            PangleSplashAdManager.shared.loadAndShowSplashAd(
                slotID: "104085288",
                tolerateTimeout: 3.0
            ) { success, error in
                if success {
                    print("✅ 开屏广告展示完成")
                    // 可以在这里进行后续操作，比如跳转到主界面
                } else if let error = error {
                    print("❌ 开屏广告展示失败: \(error.localizedDescription)")
                    // 即使广告失败，也要进行后续操作
                }
            }
        }
    }
}

// MARK: - 示例4: 自定义控制逻辑

class SplashAdController {

    /// 智能展示开屏广告
    /// - 会检查各种条件，确保在合适的时机展示
    static func showSplashAdIfAppropriate() {
        // 1. 检查用户是否同意隐私政策
        let onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")
        guard onboardingCompleted else {
            print("⚠️ 用户未同意隐私政策")
            return
        }

        // 2. 检查SDK是否已初始化
        guard PangleAdManager.shared.isSDKInitialized() else {
            print("⚠️ SDK未初始化")
            return
        }

        // 3. 检查今天是否已经展示过（可选的频率控制）
        if shouldShowTodaySplashAd() {
            loadAndShowSplashAd()
        } else {
            print("⚠️ 今日已展示开屏广告，跳过")
        }
    }

    /// 检查今天是否应该展示开屏广告
    private static func shouldShowTodaySplashAd() -> Bool {
        let lastShowDate = UserDefaults.standard.object(forKey: "lastSplashAdShowDate") as? Date
        let calendar = Calendar.current

        if let lastDate = lastShowDate {
            // 如果上次展示是今天，则不再展示
            return !calendar.isDateInToday(lastDate)
        }

        // 从未展示过，可以展示
        return true
    }

    /// 加载并展示开屏广告
    private static func loadAndShowSplashAd() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            PangleSplashAdManager.shared.loadAndShowSplashAd(
                slotID: "104085288",
                tolerateTimeout: 3.0
            ) { success, error in
                if success {
                    // 记录展示时间
                    UserDefaults.standard.set(Date(), forKey: "lastSplashAdShowDate")
                    print("✅ 开屏广告展示成功，已记录展示时间")
                } else if let error = error {
                    print("❌ 开屏广告展示失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - 示例5: 在特定视图中触发

struct SplashAdTriggerView: View {
    @State private var showingAd = false

    var body: some View {
        VStack {
            Button("手动展示开屏广告") {
                showSplashAd()
            }
            .padding()
        }
    }

    private func showSplashAd() {
        guard PangleAdManager.shared.isSDKInitialized() else {
            print("⚠️ SDK未初始化")
            return
        }

        PangleSplashAdManager.shared.loadAndShowSplashAd(
            slotID: "104085288",
            tolerateTimeout: 3.0
        ) { success, error in
            if success {
                print("✅ 开屏广告展示成功")
            } else {
                print("❌ 开屏广告展示失败")
            }
        }
    }
}

// MARK: - 使用建议

/*
 推荐使用方式：

 1. 应用首次启动
    - 在用户同意隐私政策后初始化SDK
    - 初始化成功后展示开屏广告

 2. 应用冷启动（非首次）
    - 应用启动时自动展示开屏广告
    - 延迟0.2秒确保UI已加载

 3. 应用从后台返回（可选）
    - 根据业务需求决定是否展示
    - 可以添加频率控制（如每天一次）

 4. 错误处理
    - 始终处理广告加载失败的情况
    - 即使广告失败也要继续应用流程

 5. 性能优化
    - 使用适当的延迟时间（0.1-0.3秒）
    - 不要阻塞主线程
    - 设置合理的超时时间（3-5秒）
 */
