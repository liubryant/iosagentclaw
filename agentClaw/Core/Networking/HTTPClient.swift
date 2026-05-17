import Foundation

enum HTTPClientError: Error, LocalizedError {
    case invalidResponse
    case statusCode(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .statusCode(let code, let body):
            return body.isEmpty ? "HTTP \(code)" : "HTTP \(code): \(body)"
        }
    }
}

protocol HTTPClient {
    func data(for request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void)
}

final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        HTTPDebugLogger.logRequest(request)
        let task = session.dataTask(with: request) { data, response, error in
            HTTPDebugLogger.logResponse(data: data, response: response, error: error)

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(HTTPClientError.invalidResponse))
                return
            }

            let responseData = data ?? Data()
            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: responseData, encoding: .utf8) ?? ""
                completion(.failure(HTTPClientError.statusCode(httpResponse.statusCode, body)))
                return
            }

            completion(.success(responseData))
        }
        task.resume()
    }
}

enum HTTPDebugLogger {
    static func logRequest(_ request: URLRequest) {
        print("----- AgentClaw HTTP Request -----")
        print("URL: \(request.url?.absoluteString ?? "-")")
        print("Method: \(request.httpMethod ?? "-")")

        let headers = request.allHTTPHeaderFields ?? [:]
        if headers.isEmpty {
            print("Headers: {}")
        } else {
            print("Headers:")
            headers.sorted { $0.key < $1.key }.forEach { key, value in
                print("  \(key): \(maskedHeaderValue(value, for: key))")
            }
        }

        if let body = request.httpBody, body.isEmpty == false {
            print("Body: \(prettyJSON(body) ?? String(data: body, encoding: .utf8) ?? "<\(body.count) bytes>")")
        } else {
            print("Body: <empty>")
        }
        print("----------------------------------")
    }

    static func logResponse(data: Data?, response: URLResponse?, error: Error?) {
        print("----- AgentClaw HTTP Response ----")
        if let httpResponse = response as? HTTPURLResponse {
            print("Status: \(httpResponse.statusCode)")
            print("URL: \(httpResponse.url?.absoluteString ?? "-")")
            if httpResponse.allHeaderFields.isEmpty == false {
                print("Headers:")
                httpResponse.allHeaderFields.keys
                    .compactMap { $0 as? String }
                    .sorted()
                    .forEach { key in
                        let value = httpResponse.allHeaderFields[key] ?? ""
                        print("  \(key): \(value)")
                    }
            }
        } else {
            print("Status: <no http response>")
        }

        if let data = data, data.isEmpty == false {
            print("Body: \(prettyJSON(data) ?? String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>")")
        } else {
            print("Body: <empty>")
        }

        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
        print("----------------------------------")
    }

    private static func maskedHeaderValue(_ value: String, for key: String) -> String {
        if key.lowercased() == "authorization" {
            if value.count <= 16 {
                return "<redacted>"
            }
            return "\(value.prefix(12))...<redacted>"
        }
        return value
    }

    private static func prettyJSON(_ data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data, options: []),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
            let text = String(data: prettyData, encoding: .utf8)
        else {
            return nil
        }
        return text
    }
}
