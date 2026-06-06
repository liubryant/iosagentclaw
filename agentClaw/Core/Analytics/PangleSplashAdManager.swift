//
//  PangleSplashAdManager.swift
//  agentClaw
//
//  Created by Liuzheng on 2026/5/23.
//  Email: bryant_liu24@126.com
//

import Foundation
import UIKit

#if canImport(BUAdSDK)
import BUAdSDK
#endif

/// 穿山甲开屏广告管理类
///
/// 重要注意事项：
/// 1. 需要确保在SDK初始化成功后再进行广告请求
/// 2. 聚合SDK通过广告位ID发起请求，切记不要使用混淆
/// 3. 融合场景下仅支持自渲染开屏
/// 4. 开屏广告展示时机：在loadSuccess回调中调用show方法展示广告
/// 5. rootViewController建议使用应用当前window的rootViewController
/// 6. 开屏内部视图生命周期由SDK管理，关注BUSplashAd对象
/// 7. 不建议开屏广告使用preload首次预缓存功能
class PangleSplashAdManager: NSObject {

    static let shared = PangleSplashAdManager()
    static let defaultSplashSlotID = "104085288"

    #if canImport(BUAdSDK)
    private var splashAd: BUSplashAd?
    #endif

    private var isLoading = false
    private var didRequestSplashThisSession = false
    private var completionHandler: ((Bool, Error?) -> Void)?

    var shouldRequestSplashThisSession: Bool {
        !didRequestSplashThisSession && !isLoading
    }

    private override init() {
        super.init()
    }

    func loadAndShowDefaultSplashAd(completion: ((Bool, Error?) -> Void)? = nil) {
        loadAndShowSplashAd(slotID: Self.defaultSplashSlotID, completion: completion)
    }

    /// 加载并展示开屏广告
    /// - Parameters:
    ///   - slotID: 广告位ID（注意：不要使用混淆）
    ///   - tolerateTimeout: 超时时间（秒），默认3秒
    ///   - completion: 完成回调
    func loadAndShowSplashAd(
        slotID: String,
        tolerateTimeout: TimeInterval = 3.0,
        completion: ((Bool, Error?) -> Void)? = nil
    ) {
        #if canImport(BUAdSDK)
        guard shouldRequestSplashThisSession else {
            print("csjad splash_load_ignored_session_requested slotID=\(slotID)")
            completion?(false, nil)
            return
        }

        didRequestSplashThisSession = true

        // 检查SDK是否已初始化
        guard PangleAdManager.shared.isSDKInitialized() else {
            let error = NSError(
                domain: "PangleSplashAdManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "SDK未初始化，请先初始化SDK"]
            )
            print("csjad splash_load_blocked_not_initialized slotID=\(slotID)")
            print("❌ 开屏广告加载失败：SDK未初始化")
            completion?(false, error)
            return
        }

        // 检查是否正在加载
        guard !isLoading else {
            print("csjad splash_load_ignored_loading slotID=\(slotID)")
            print("⚠️ 开屏广告正在加载中，请勿重复请求")
            return
        }

        isLoading = true
        self.completionHandler = completion

        print("csjad splash_load_start appID=\(PangleAdManager.shared.appID), slotID=\(slotID), timeout=\(tolerateTimeout)")
        print("开始加载开屏广告 - SlotID: \(slotID), 超时时间: \(tolerateTimeout)秒")

        // 创建开屏广告配置
        let slotAd = BUAdSlot()
        slotAd.id = slotID

        // 创建开屏广告对象
        splashAd = BUSplashAd(slot: slotAd, adSize: UIScreen.main.bounds.size)
        splashAd?.delegate = self
        splashAd?.tolerateTimeout = tolerateTimeout

        // 加载广告（在loadSuccess回调中展示广告）
        splashAd?.loadData()

        #else
        didRequestSplashThisSession = true
        let error = NSError(
            domain: "PangleSplashAdManager",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: "穿山甲SDK未安装"]
        )
        print("csjad splash_sdk_missing slotID=\(slotID)")
        completion?(false, error)
        #endif
    }

    /// 获取当前应用的rootViewController
    /// 建议使用keyWindow.rootViewController
    private func getRootViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            // iOS 13+使用connectedScenes获取keyWindow
            let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            return windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        } else {
            // iOS 13以下使用传统方式
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }
}

// MARK: - BUSplashAdDelegate

#if canImport(BUAdSDK)
extension PangleSplashAdManager: BUMSplashAdDelegate {

    /// 广告数据加载成功回调
    func splashAdLoadSuccess(_ splashAd: BUSplashAd) {
        print("csjad splash_load_success slotID=\(splashAd.slotID)")
        print("✅ 开屏广告加载成功")

        guard let rootViewController = getRootViewController() else {
            isLoading = false
            let error = NSError(
                domain: "PangleSplashAdManager",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "未找到 rootViewController，无法展示开屏广告"]
            )
            print("csjad splash_show_fail_no_root slotID=\(splashAd.slotID)")
            completionHandler?(false, error)
            completionHandler = nil
            return
        }

        print("csjad splash_show_call slotID=\(splashAd.slotID), root=\(type(of: rootViewController))")
        splashAd.showSplashView(inRootViewController: rootViewController)
    }

    /// 广告数据加载失败回调
    func splashAdLoadFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        isLoading = false
        print("csjad splash_load_fail slotID=\(splashAd.slotID), code=\(error?.code ?? -1), error=\(error?.localizedDescription ?? "未知错误")")
        print("❌ 开屏广告加载失败: \(error?.localizedDescription ?? "未知错误")")

        let nsError = NSError(
            domain: "PangleSplashAdManager",
            code: Int(error?.code ?? -1),
            userInfo: [NSLocalizedDescriptionKey: error?.localizedDescription ?? "未知错误"]
        )
        completionHandler?(false, nsError)
        completionHandler = nil
    }

    /// 广告渲染成功回调
    func splashAdRenderSuccess(_ splashAd: BUSplashAd) {
        print("csjad splash_render_success slotID=\(splashAd.slotID)")
        print("✅ 开屏广告渲染成功")
    }

    /// 广告渲染失败回调
    func splashAdRenderFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        print("csjad splash_render_fail slotID=\(splashAd.slotID), code=\(error?.code ?? -1), error=\(error?.localizedDescription ?? "")")
        print("❌ 开屏广告渲染失败: \(error?.localizedDescription ?? "")")
    }

    /// 广告即将展示回调
    func splashAdWillShow(_ splashAd: BUSplashAd) {
        print("csjad splash_will_show slotID=\(splashAd.slotID)")
        print("📱 开屏广告即将展示")
    }

    /// 广告已展示回调
    func splashAdDidShow(_ splashAd: BUSplashAd) {
        isLoading = false
        completionHandler?(true, nil)
        completionHandler = nil
        print("csjad splash_did_show slotID=\(splashAd.slotID)")
        print("✅ 开屏广告已展示")
    }

    /// 广告点击回调
    func splashAdDidClick(_ splashAd: BUSplashAd) {
        print("csjad splash_click slotID=\(splashAd.slotID)")
        print("👆 开屏广告被点击")
    }

    /// 广告关闭回调
    func splashAdDidClose(_ splashAd: BUSplashAd, closeType: BUSplashAdCloseType) {
        isLoading = false
        print("csjad splash_close slotID=\(splashAd.slotID), closeType=\(closeType.rawValue)")
        print("🔚 开屏广告已关闭，类型: \(closeType.rawValue)")
        splashAd.mediation?.destoryAd()
        self.splashAd = nil
    }

    /// 广告控制器关闭回调
    func splashAdViewControllerDidClose(_ splashAd: BUSplashAd) {
        print("csjad splash_view_controller_close slotID=\(splashAd.slotID)")
        print("🔚 开屏广告控制器已关闭")
    }

    /// 其他控制器关闭回调
    func splashDidCloseOtherController(_ splashAd: BUSplashAd, interactionType: BUInteractionType) {
        print("csjad splash_other_controller_close slotID=\(splashAd.slotID), interactionType=\(interactionType.rawValue)")
        print("🔚 其他控制器已关闭")
    }

    /// 视频播放完成回调
    func splashVideoAdDidPlayFinish(_ splashAd: BUSplashAd, didFailWithError error: Error?) {
        if let error = error {
            print("csjad splash_video_finish_fail slotID=\(splashAd.slotID), error=\(error.localizedDescription)")
            print("❌ 视频播放失败: \(error.localizedDescription)")
        } else {
            print("csjad splash_video_finish_success slotID=\(splashAd.slotID)")
            print("✅ 视频播放完成")
        }
    }

    func splashAdDidShowFailed(_ splashAd: BUSplashAd, error: Error) {
        isLoading = false
        print("csjad splash_show_fail slotID=\(splashAd.slotID), error=\(error.localizedDescription)")
        completionHandler?(false, error)
        completionHandler = nil
    }
}
#endif
