import Foundation
import UIKit

final class AuthService {
    static let shared = AuthService()

    private var baseURL: String {
        let url = EnvironmentManager.shared.currentEnvironment.baseURL
        return url.hasSuffix("/v1") ? String(url.dropLast(3)) : url
    }

    struct LoginResult {
        let phone: String
        let isNewUser: Bool
        let accessToken: String
    }

    private func apiURL(_ path: String) -> URL {
        URL(string: "\(baseURL)\(path)")!
    }

    private func postJSON(_ url: URL, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let code = json["code"]
        let success = (code as? Int == 0) || (code as? String == "0")
        if !success {
            let msg = json["msg"] as? String ?? "请求失败"
            throw NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return json
    }

    func sendCode(phone: String) async throws {
        let url = apiURL("/im/bot/login-code")
        _ = try await postJSON(url, body: ["phone": phone])
    }

    func loginByPassword(phone: String, password: String) async throws -> LoginResult {
        let url = apiURL("/im/bot/login-by-password")
        let (deviceModel, osVersion) = await MainActor.run {
            (UIDevice.current.model, UIDevice.current.systemVersion)
        }
        let json = try await postJSON(url, body: [
            "phone": phone,
            "password": password,
            "deviceModel": deviceModel,
            "osVersion": osVersion,
            "appName": "AgentClaw"
        ])
        let data = json["data"] as? [String: Any] ?? [:]
        let returnedPhone = (data["phone"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? phone
        let isNewUser = data["newUser"] as? Bool ?? false
        let token = (data["accessToken"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? (data["token"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? ""
        return LoginResult(phone: returnedPhone, isNewUser: isNewUser, accessToken: token)
    }

    func loginByCode(phone: String, code: String) async throws -> LoginResult {
        let url = apiURL("/im/bot/login-by-code")
        let (deviceModel, osVersion) = await MainActor.run {
            (UIDevice.current.model, UIDevice.current.systemVersion)
        }
        let json = try await postJSON(url, body: [
            "phone": phone,
            "code": code,
            "deviceModel": deviceModel,
            "osVersion": osVersion,
            "appName": "AgentClaw"
        ])
        let data = json["data"] as? [String: Any] ?? [:]
        let returnedPhone = (data["phone"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? phone
        let isNewUser = data["newUser"] as? Bool ?? false
        let token = (data["accessToken"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? (data["token"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? ""
        return LoginResult(phone: returnedPhone, isNewUser: isNewUser, accessToken: token)
    }

    func setPassword(phone: String, code: String, password: String) async throws {
        let url = apiURL("/im/bot/set-password")
        _ = try await postJSON(url, body: [
            "phone": phone,
            "code": code,
            "password": password
        ])
    }

    func deleteAccount(phone: String, code: String) async throws {
        let url = apiURL("/im/bot/remove_account")
        _ = try await postJSON(url, body: [
            "phone": phone,
            "code": code
        ])
    }
}
