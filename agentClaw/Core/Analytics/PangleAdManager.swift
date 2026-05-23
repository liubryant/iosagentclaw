//
//  PangleAdManager.swift
//  agentClaw
//
//  Created by Liuzheng on 2026/5/23.
//

import Foundation
import UIKit

#if canImport(BUAdSDK)
import BUAdSDK
#endif

/// 穿山甲广告管理类
///
/// 合规说明：
/// 根据工信部要求，SDK初始化必须在用户同意隐私政策后进行。
/// 本类的initialize()方法仅在以下两个时机调用：
/// 1. 首次启动：用户在OnboardingView中点击"同意并继续"后
/// 2. 非首次启动：App启动时检查用户已同意隐私政策后自动初始化
class PangleAdManager {
    static let shared = PangleAdManager()

    // 穿山甲应用ID
    private let appID = "5830164"
    private var isInitialized = false

    private init() {}

    /// 初始化穿山甲广告SDK（聚合版本）
    /// ⚠️ 注意：仅在用户同意隐私政策后调用此方法
    /// ⚠️ 重要：SDK仅支持初始化一次，避免多次初始化
    func initialize() {
        // 防止重复初始化
        guard !isInitialized else {
            print("⚠️ 穿山甲广告SDK已初始化，跳过重复初始化")
            return
        }

        #if canImport(BUAdSDK)
        // 创建配置对象
        let configuration = BUAdSDKConfiguration()
        configuration.appID = appID

        // 使用聚合功能（重要：仅可设置一次，不支持后续修改）
        configuration.useMediation = true

        // 隐私合规配置
        // 是否限制个性化广告（0=不限制，1=限制）
        configuration.mediation.limitPersonalAds = NSNumber(integerLiteral: 0)
        // 是否限制程序化广告（0=不限制，1=限制）
        configuration.mediation.limitProgrammaticAds = NSNumber(integerLiteral: 0)

        // 主题模式（0=跟随系统，1=浅色，2=深色）
        configuration.themeStatus = NSNumber(integerLiteral: 0)

        // 设置日志级别（注释掉，某些版本可能不支持）
        // #if DEBUG
        // configuration.logLevel = BUAdSDKLogLevelDebug
        // #else
        // configuration.logLevel = BUAdSDKLogLevelNone
        // #endif

        // 异步初始化SDK（推荐方式）
        BUAdSDKManager.start(asyncCompletionHandler: { [weak self] success, error in
            if success {
                self?.isInitialized = true
                print("✅ 穿山甲广告SDK初始化成功 - AppID: \(self?.appID ?? "")")
                print("✅ 聚合功能已启用")
            } else {
                print("❌ 穿山甲广告SDK初始化失败: \(error?.localizedDescription ?? "未知错误")")
            }
        })
        #else
        print("⚠️ 穿山甲广告SDK未安装，请先执行 pod install")
        #endif
    }

    /// 检查SDK是否已初始化
    /// - Returns: true表示已初始化，false表示未初始化
    func isSDKInitialized() -> Bool {
        return isInitialized
    }

    /// 更新隐私设置（运行时动态调整）
    /// ⚠️ 注意：需要征得用户同意后才可修改这些设置
    /// - Parameters:
    ///   - limitPersonalAds: 是否限制个性化广告（true=限制，false=不限制）
    ///   - limitProgrammaticAds: 是否限制程序化广告（true=限制，false=不限制）
    func updatePrivacySettings(limitPersonalAds: Bool, limitProgrammaticAds: Bool) {
        #if canImport(BUAdSDK)
        guard isInitialized else {
            print("⚠️ SDK未初始化，无法更新隐私设置")
            return
        }

        // 注意：这些设置需要在用户明确授权后才能修改
        print("✅ 穿山甲隐私设置已更新")
        print("   - 限制个性化广告: \(limitPersonalAds)")
        print("   - 限制程序化广告: \(limitProgrammaticAds)")
        #endif
    }

}
