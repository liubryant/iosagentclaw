//
//  UMengAnalytics.swift
//  agentClaw
//
//  Created by Liuzheng on 2026/5/23.
//  Email: bryant_liu24@126.com
//

import Foundation

#if canImport(UMCommon)
import UMCommon
#endif

/// 友盟统计管理类
///
/// 合规说明：
/// 根据工信部要求，SDK初始化必须在用户同意隐私政策后进行。
/// 本类的initialize()方法仅在以下两个时机调用：
/// 1. 首次启动：用户在OnboardingView中点击"同意并继续"后
/// 2. 非首次启动：App启动时检查用户已同意隐私政策后自动初始化
class UMengAnalytics {
    static let shared = UMengAnalytics()

    private let appKey = "6a10918f9a7f376488e523a1"
    private let channel = "App Store" // 渠道名称，可根据需要修改
    private var isInitialized = false

    private init() {}

    /// 初始化友盟统计
    /// ⚠️ 注意：仅在用户同意隐私政策后调用此方法
    func initialize() {
        // 防止重复初始化
        guard !isInitialized else {
            print("⚠️ 友盟统计已初始化，跳过重复初始化")
            return
        }
        #if canImport(UMCommon)
        // 设置友盟appkey
        UMConfigure.initWithAppkey(appKey, channel: channel)

        // 设置日志输出级别（调试时可以设置为UMCommonLogLevelDebug，发布时改为UMCommonLogLevelOff）
        #if DEBUG
        UMConfigure.setLogEnabled(true)
        #else
        UMConfigure.setLogEnabled(false)
        #endif

        isInitialized = true
        print("✅ 友盟统计初始化成功 - AppKey: \(appKey)")
        #else
        print("⚠️ 友盟统计SDK未安装，请先执行 pod install")
        #endif
    }

    /// 记录事件
    /// - Parameters:
    ///   - eventId: 事件ID
    ///   - attributes: 事件属性（可选）
    func logEvent(_ eventId: String, attributes: [String: Any]? = nil) {
        #if canImport(UMCommon)
        if let attributes = attributes {
            MobClick.event(eventId, attributes: attributes)
        } else {
            MobClick.event(eventId)
        }
        #endif
    }

    /// 页面开始统计
    /// - Parameter pageName: 页面名称
    func pageBegin(_ pageName: String) {
        #if canImport(UMCommon)
        MobClick.beginLogPageView(pageName)
        #endif
    }

    /// 页面结束统计
    /// - Parameter pageName: 页面名称
    func pageEnd(_ pageName: String) {
        #if canImport(UMCommon)
        MobClick.endLogPageView(pageName)
        #endif
    }
}
