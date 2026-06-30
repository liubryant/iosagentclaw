import Foundation
import UIKit

// Alipay payment result
enum AlipayResult {
    case success
    case cancelled
    case failed(String)
}

// Alipay bridge - wraps AlipaySDK when available, degrades gracefully otherwise.
// After running 'pod install' with 'pod AlipaySDK-iOS', the SDK will be available.
final class AlipayBridge: NSObject {
    static let shared = AlipayBridge()

    // URL scheme registered in Info.plist (CFBundleURLTypes)
    static let urlScheme = "agentclawpay"

    private var pendingCallback: ((AlipayResult) -> Void)?

    // Called by AppDelegate.application(_:open:options:)
    func handleOpenURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == Self.urlScheme.lowercased() else { return false }
        // When AlipaySDK is integrated:
        // AlipaySDK.defaultService().processOrder(withPaymentResult: url, standbyCallback: nil)
        // For now, parse result from URL (Alipay appends memo/result to callback)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let memo = components?.queryItems?.first(where: { $0.name == "memo" })?.value ?? ""
        let resultStatus = components?.queryItems?.first(where: { $0.name == "resultStatus" })?.value ?? ""
        if resultStatus == "9000" {
            pendingCallback?(.success)
        } else if resultStatus == "6001" {
            pendingCallback?(.cancelled)
        } else {
            pendingCallback?(.failed(memo.isEmpty ? "支付未完成，请稍后重试" : memo))
        }
        pendingCallback = nil
        return true
    }

    func pay(orderString: String, completion: @escaping (AlipayResult) -> Void) {
        guard !orderString.isEmpty else {
            completion(.failed("支付宝参数错误"))
            return
        }
        pendingCallback = completion

        // When AlipaySDK pod is installed, replace this block with:
        // AlipaySDK.defaultService().payOrder(orderString, fromScheme: Self.urlScheme, callback: { result in
        //     let status = result?["resultStatus"] as? String ?? ""
        //     if status == "9000" { completion(.success) }
        //     else if status == "6001" { completion(.cancelled) }
        //     else { completion(.failed(result?["memo"] as? String ?? "支付失败")) }
        // })

        // Fallback: open Alipay H5 URL if native SDK not yet linked
        if let alipayURL = URL(string: "alipays://\(orderString)"),
           UIApplication.shared.canOpenURL(alipayURL) {
            UIApplication.shared.open(alipayURL)
        } else if let alipayURL = URL(string: "alipay://\(orderString)"),
                  UIApplication.shared.canOpenURL(alipayURL) {
            UIApplication.shared.open(alipayURL)
        } else {
            pendingCallback = nil
            completion(.failed("请先安装支付宝"))
        }
    }
}
