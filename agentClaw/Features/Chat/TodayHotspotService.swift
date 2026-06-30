import Foundation

struct TodayHotspotItem {
    let title: String
    let subtitle: String
    let prompt: String
}

final class TodayHotspotService {
    static let shared = TodayHotspotService()
    private init() {}

    private var apiBaseURL: URL {
        // Strip /v1 suffix to reach the API root (same logic as Android TodayHotspotService)
        let base = EnvironmentManager.shared.baseURL.absoluteString
        let stripped = base.hasSuffix("/v1") ? String(base.dropLast(3)) : base
        return URL(string: stripped)!
    }

    func load(completion: @escaping (Result<[TodayHotspotItem], Error>) -> Void) {
        let url = apiBaseURL.appendingPathComponent("im/bot/navi/hotspots")
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(Self.error("响应解析失败")))
                return
            }
            // code 字段可能是 Int 或 String
            let code = (root["code"] as? String) ?? (root["code"] as? Int).map { "\($0)" } ?? ""
            guard code == "0", let array = root["data"] as? [[String: Any]] else {
                let msg = root["msg"] as? String ?? "今日热点加载失败"
                completion(.failure(Self.error(msg)))
                return
            }
            let items = array.compactMap { item -> TodayHotspotItem? in
                let title  = (item["title"]          as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                let sub    = (item["subtitle"]        as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                let prompt = (item["promptTemplate"]  as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                guard !title.isEmpty, !sub.isEmpty, !prompt.isEmpty else { return nil }
                return TodayHotspotItem(title: title, subtitle: sub, prompt: prompt)
            }
            if items.isEmpty {
                completion(.failure(Self.error("今日热点没有可展示内容")))
            } else {
                completion(.success(items))
            }
        }.resume()
    }

    private static func error(_ msg: String) -> Error {
        NSError(domain: "TodayHotspot", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
