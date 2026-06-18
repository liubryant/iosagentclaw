//
//  TrackingAuthorization.swift
//  agentClaw
//

import Foundation
import AppTrackingTransparency

/// App 跟踪透明度（ATT）权限请求的统一入口。
/// 必须在统计 / 广告 SDK 初始化之前调用，确保权限弹窗先于任何可能用于跟踪用户的数据采集出现。
enum TrackingAuthorization {
    /// 用户尚未做出选择时弹出系统权限请求，做出选择（或已经做过选择）后再继续。
    static func requestIfNeeded(then proceed: @escaping () -> Void) {
        guard #available(iOS 14, *) else {
            proceed()
            return
        }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            proceed()
            return
        }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async {
                proceed()
            }
        }
    }

    /// 当前是否被允许进行广告跟踪，用于设置穿山甲 forbiddenIDFA 等参数。
    static var isTrackingAuthorized: Bool {
        guard #available(iOS 14, *) else { return true }
        return ATTrackingManager.trackingAuthorizationStatus == .authorized
    }
}
