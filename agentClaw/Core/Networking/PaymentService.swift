import Foundation

struct VipProduct: Identifiable, Codable {
    let id: String
    let name: String
    let price: String
    let description: String

    init(from dict: [String: Any]) {
        id = dict["id"] as? String ?? ""
        name = dict["name"] as? String ?? ""
        price = dict["price"] as? String ?? (dict["price"] as? Double).map { String($0) } ?? ""
        description = dict["description"] as? String ?? ""
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

struct OrderResult {
    let orderId: String
    let aliPayOrderString: String?
    let isMock: Bool
}

final class PaymentService {
    static let shared = PaymentService()

    private var baseURL: String {
        let url = EnvironmentManager.shared.currentEnvironment.baseURL
        let stripped = url.hasSuffix("/v1") ? String(url.dropLast(3)) : url
        return "\(stripped)/im/bot/navi/vip"
    }

    static let alipayAppID = "2021006169619056"

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

    func createOrder(token: String, productId: String, payChannel: String) async throws -> OrderResult {
        let body: [String: Any] = [
            "productId": productId,
            "payChannel": payChannel,
            "appid": Self.alipayAppID
        ]
        let json = try await makeRequest("/orders", method: "POST", token: token, body: body)
        let data = json["data"] as? [String: Any] ?? [:]
        let orderId = (data["orderId"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? (data["id"] as? String) ?? ""
        let orderString = (data["aliPayOrderString"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? (data["orderString"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? (data["alipayOrderString"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let isMock = data["mock"] as? Bool ?? false
        return OrderResult(orderId: orderId, aliPayOrderString: orderString, isMock: isMock)
    }

    func queryOrder(token: String, orderId: String) async throws -> String {
        let json = try await makeRequest("/orders/\(orderId)", token: token)
        let data = json["data"] as? [String: Any] ?? [:]
        return data["status"] as? String ?? ""
    }
}
