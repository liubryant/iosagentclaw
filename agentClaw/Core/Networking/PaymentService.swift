import Foundation

struct VipProduct: Identifiable, Codable {
    let id: String
    let name: String
    let price: String
    let description: String
    /// App Store Connect 内购商品 ID。优先取后端下发字段；缺省时按套餐时长本地推断。
    let appleProductId: String

    init(from dict: [String: Any]) {
        let pid = dict["id"] as? String ?? ""
        id = pid
        name = dict["name"] as? String ?? ""
        price = dict["price"] as? String ?? (dict["price"] as? Double).map { String($0) } ?? ""
        description = dict["description"] as? String ?? ""

        let fromServer = (dict["appleProductId"] as? String)
            ?? (dict["iosProductId"] as? String)
            ?? (dict["appstoreProductId"] as? String)
            ?? (dict["sku"] as? String)
        if let s = fromServer, !s.isEmpty {
            appleProductId = s
        } else {
            appleProductId = VipProduct.inferAppleProductId(
                id: pid, name: dict["name"] as? String ?? "", desc: dict["description"] as? String ?? ""
            )
        }
    }

    /// 骨架占位套餐：接口返回前先撑起列表布局，只展示名称与介绍，不展示价格。
    init(placeholderName: String, description: String) {
        id = ""
        name = placeholderName
        price = ""
        self.description = description
        appleProductId = ""
    }

    /// 后端未下发 appleProductId 时的兜底映射：按周/月/年关键字匹配。
    static func inferAppleProductId(id: String, name: String, desc: String) -> String {
        let haystack = "\(id) \(name) \(desc)".lowercased()
        if haystack.contains("year") || haystack.contains("年") || haystack.contains("annual") {
            return "cn.agent.vip.year"
        }
        if haystack.contains("month") || haystack.contains("月") {
            return "cn.agent.vip.month"
        }
        if haystack.contains("week") || haystack.contains("周") || haystack.contains("星期") {
            return "cn.agent.vip.week"
        }
        return ""
    }
}

struct MembershipStatus {
    let active: Bool
    let expiresAt: String?
    let freeVideoDaily: Int?
    let freeImageDaily: Int?
    let vipVideoDaily: Int?
    let vipImageDaily: Int?
    let vipRemindDays: Int?
}

final class PaymentService {
    static let shared = PaymentService()

    private var baseURL: String {
        let url = EnvironmentManager.shared.currentEnvironment.baseURL
        let stripped = url.hasSuffix("/v1") ? String(url.dropLast(3)) : url
        return "\(stripped)/im/bot/navi/vip"
    }

    private func makeRequest(_ path: String, method: String = "GET", token: String? = nil, body: [String: Any]? = nil) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let code = json["code"]
        let success = (code as? Int == 0) || (code as? String == "0")
        if !success {
            let msg = json["msg"] as? String ?? "请求失败"
            throw NSError(domain: "PaymentService", code: 0, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return json
    }

    func loadProducts() async throws -> [VipProduct] {
        let json = try await makeRequest("/products")
        let data = json["data"]
        var arr: [[String: Any]] = []
        if let list = data as? [[String: Any]] {
            arr = list
        } else if let obj = data as? [String: Any] {
            arr = (obj["list"] ?? obj["products"] ?? obj["items"]) as? [[String: Any]] ?? []
        }
        return arr.map { VipProduct(from: $0) }
    }

    func loadMembership(token: String) async throws -> MembershipStatus {
        let json = try await makeRequest("/membership", token: token)
        return membershipStatus(from: json)
    }

    func loadPublicMembership() async throws -> MembershipStatus {
        let json = try await makeRequest("/membership")
        return membershipStatus(from: json)
    }

    private func membershipStatus(from json: [String: Any]) -> MembershipStatus {
        let data = json["data"] as? [String: Any] ?? [:]
        let active = (data["active"] as? Bool) ?? (data["isVip"] as? Bool) ?? (data["isMember"] as? Bool) ?? false
        let expires = (data["expiresAt"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let quota = data["quota"] as? [String: Any]
        return MembershipStatus(
            active: active,
            expiresAt: expires,
            freeVideoDaily: quota?["freeVideoDaily"] as? Int,
            freeImageDaily: quota?["freeImageDaily"] as? Int,
            vipVideoDaily: quota?["vipVideoDaily"] as? Int,
            vipImageDaily: quota?["vipImageDaily"] as? Int,
            vipRemindDays: quota?["vipRemindDays"] as? Int
        )
    }

    /// 苹果内购校验：把 StoreKit 返回的已签名交易(JWS)交给后端，
    /// 后端向 Apple 校验后发放会员并返回最新会员状态。
    /// 后端接口：POST {baseURL}/im/bot/navi/vip/apple/verify
    func verifyApplePurchase(
        token: String,
        productId: String,
        appleProductId: String,
        transactionId: String,
        jws: String
    ) async throws -> MembershipStatus {
        let body: [String: Any] = [
            "productId": productId,
            "appleProductId": appleProductId,
            "transactionId": transactionId,
            "jws": jws,
            "platform": "ios",
            "bundleId": Bundle.main.bundleIdentifier ?? ""
        ]
        let json = try await makeRequest("/apple/verify", method: "POST", token: token, body: body)
        let data = json["data"] as? [String: Any] ?? [:]
        let active = (data["active"] as? Bool) ?? (data["isVip"] as? Bool) ?? (data["isMember"] as? Bool) ?? true
        let expires = (data["expiresAt"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let quota = data["quota"] as? [String: Any]
        return MembershipStatus(
            active: active,
            expiresAt: expires,
            freeVideoDaily: quota?["freeVideoDaily"] as? Int,
            freeImageDaily: quota?["freeImageDaily"] as? Int,
            vipVideoDaily: quota?["vipVideoDaily"] as? Int,
            vipImageDaily: quota?["vipImageDaily"] as? Int,
            vipRemindDays: quota?["vipRemindDays"] as? Int
        )
    }

    func queryOrder(token: String, orderId: String) async throws -> String {
        let json = try await makeRequest("/orders/\(orderId)", token: token)
        let data = json["data"] as? [String: Any] ?? [:]
        return data["status"] as? String ?? ""
    }
}
