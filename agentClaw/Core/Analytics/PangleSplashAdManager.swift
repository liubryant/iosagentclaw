//
//  PangleSplashAdManager.swift
//  agentClaw
//
//  Created by Liuzheng on 2026/5/23.
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

    #if canImport(BUAdSDK)
    private var splashAd: BUSplashAd?
    #endif

    private var isLoading = false
    private var completionHandler: ((Bool, Error?) -> Void)?

    private override init() {
        super.init()
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
        // 检查SDK是否已初始化
        guard PangleAdManager.shared.isSDKInitialized() else {
            let error = NSError(
                domain: "PangleSplashAdManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "SDK未初始化，请先初始化SDK"]
            )
            print("❌ 开屏广告加载失败：SDK未初始化")
            completion?(false, error)
            return
        }

        // 检查是否正在加载
        guard !isLoading else {
            print("⚠️ 开屏广告正在加载中，请勿重复请求")
            return
        }

        isLoading = true
        self.completionHandler = completion

        print("📱 开始加载开屏广告 - SlotID: \(slotID), 超时时间: \(tolerateTimeout)秒")

        // 创建开屏广告配置
        let slotAd = BUAdSlot()
        slotAd.id = slotID

        // 创建开屏广告对象
        splashAd = BUSplashAd(slot: slotAd, adSize: UIScreen.main.bounds.size)
        splashAd?.delegate = self
        splashAd?.tolerateTimeout = tolerateTimeout

        // 加载广告（注意：在loadSuccess回调中展示广告）
        splashAd?.loadData()

        #else
        let error = NSError(
            domain: "PangleSplashAdManager",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: "穿山甲SDK未安装"]
        )
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
extension PangleSplashAdManager: BUSplashAdDelegate {

    /// 广告数据加载成功回调
    func splashAdLoadSuccess(_ splashAd: BUSplashAd) {
        print("✅ 开屏广告加载成功")
        isLoading = false
        completionHandler?(true, nil)
        completionHandler = nil
    }

    /// 广告数据加载失败回调
    func splashAdLoadFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        isLoading = false
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
        print("✅ 开屏广告渲染成功")
    }

    /// 广告渲染失败回调
    func splashAdRenderFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        print("❌ 开屏广告渲染失败: \(error?.localizedDescription ?? "")")
    }

    /// 广告即将展示回调
    func splashAdWillShow(_ splashAd: BUSplashAd) {
        print("📱 开屏广告即将展示")
    }

    /// 广告已展示回调
    func splashAdDidShow(_ splashAd: BUSplashAd) {
        print("✅ 开屏广告已展示")
    }

    /// 广告点击回调
    func splashAdDidClick(_ splashAd: BUSplashAd) {
        print("👆 开屏广告被点击")
    }

    /// 广告关闭回调
    func splashAdDidClose(_ splashAd: BUSplashAd, closeType: BUSplashAdCloseType) {
        print("🔚 开屏广告已关闭，类型: \(closeType.rawValue)")
        self.splashAd = nil
    }

    /// 广告控制器关闭回调
    func splashAdViewControllerDidClose(_ splashAd: BUSplashAd) {
        print("🔚 开屏广告控制器已关闭")
    }

    /// 其他控制器关闭回调
    func splashDidCloseOtherController(_ splashAd: BUSplashAd, interactionType: BUInteractionType) {
        print("🔚 其他控制器已关闭")
    }

    /// 视频播放完成回调
    func splashVideoAdDidPlayFinish(_ splashAd: BUSplashAd, didFailWithError error: Error?) {
        if let error = error {
            print("❌ 视频播放失败: \(error.localizedDescription)")
        } else {
            print("✅ 视频播放完成")
        }
    }
}
#endif
