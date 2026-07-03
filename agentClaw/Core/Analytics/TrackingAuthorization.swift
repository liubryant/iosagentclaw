//
//  TrackingAuthorization.swift
//  agentClaw
//

import Foundation
import AppTrackingTransparency
import UIKit

/// App 跟踪透明度（ATT）权限请求的统一入口。
/// 必须在统计 / 广告 SDK 初始化之前调用，确保权限弹窗先于任何可能用于跟踪用户的数据采集出现。
enum TrackingAuthorization {
    private static var isRequesting = false
    /// 等待本次 ATT 结果后再执行的回调（保证 SDK 初始化一定在用户作答之后）。
    private static var pendingCompletions: [() -> Void] = []

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

        // onboarding「同意」与首页 onAppear 可能同时触发；把回调排队，避免重复弹窗，
        // 且保证所有回调都在用户作答之后再执行。
        pendingCompletions.append(proceed)
        guard !isRequesting else { return }
        isRequesting = true

        whenActive {
            // ATT 系统弹窗要求：① App 处于 active 前台；② 不要与界面转场 / 其他弹窗消失
            // 处于同一事件循环，否则系统会静默判为「拒绝」且根本不展示弹窗
            // ——这正是审核方“定位不到 ATT 弹窗”的常见原因。故延后到下一拍再请求。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ATTrackingManager.requestTrackingAuthorization { _ in
                    DispatchQueue.main.async {
                        isRequesting = false
                        let completions = pendingCompletions
                        pendingCompletions = []
                        completions.forEach { $0() }
                    }
                }
            }
        }
    }

    /// 在 App 处于前台 active 时执行；若当前非 active，则等到下一次变为 active 再执行。
    private static func whenActive(_ block: @escaping () -> Void) {
        if UIApplication.shared.applicationState == .active {
            block()
        } else {
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                block()
            }
        }
    }

    /// 当前是否被允许进行广告跟踪，用于设置穿山甲 forbiddenIDFA 等参数。
    static var isTrackingAuthorized: Bool {
        guard #available(iOS 14, *) else { return true }
        return ATTrackingManager.trackingAuthorizationStatus == .authorized
    }
}
