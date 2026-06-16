import Foundation

final class GatewayClient {
    private let imageModeMarker = "[[IMAGE_MODE]]"
    private let videoModeMarker = "[[VIDEO_MODE]]"
    private let documentModeMarker = "[[DOCUMENT_MODE]]"
    private let preferences: AppPreferences
    private let keychain: KeychainStore
    private let httpClient: HTTPClient
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        preferences: AppPreferences,
        keychain: KeychainStore,
        httpClient: HTTPClient
    ) {
        self.preferences = preferences
        self.keychain = keychain
        self.httpClient = httpClient
    }

    var config: GatewayConfig {
        GatewayConfig(
            baseURL: preferences.gatewayURL,
            token: keychain.string(for: GatewayTokenKey.gatewayToken),
            allowInsecureLocalNetwork: preferences.allowInsecureLocalNetwork
        )
    }

    func saveConfig(_ config: GatewayConfig) throws {
        preferences.gatewayURL = config.baseURL.normalizedGatewayURL
        preferences.allowInsecureLocalNetwork = config.allowInsecureLocalNetwork
        try keychain.setString(config.token, for: GatewayTokenKey.gatewayToken)
    }

    func healthCheck(completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func sendChat(
        messages: [ChatMessage],
        model: String = AppConfig.defaultChatModel,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let url = config.baseURL.normalizedGatewayURL
            .appendingPathComponent("chat")
            .appendingPathComponent("completions")
        let hasImageModeMarker = messages.contains { $0.content.contains(imageModeMarker) }
        let hasVideoModeMarker = messages.contains { $0.content.contains(videoModeMarker) }
        let hasDocumentModeMarker = messages.contains { $0.content.contains(documentModeMarker) }
        let timeout: TimeInterval
        if hasImageModeMarker || hasVideoModeMarker {
            timeout = AppConfig.mediaGenerationRequestTimeout
        } else if hasDocumentModeMarker {
            timeout = AppConfig.documentGenerationRequestTimeout
        } else {
            timeout = AppConfig.requestTimeout
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

        do {
            let requestModel = modelForRequest(
                requestedModel: model,
                hasImageModeMarker: hasImageModeMarker,
                hasVideoModeMarker: hasVideoModeMarker
            )

            request.httpBody = try encoder.encode(
                ChatCompletionRequest(
                    model: requestModel,
                    stream: false,
                    responseMode: hasVideoModeMarker ? "video_only" : nil,
                    messages: messages.map {
                        ChatCompletionRequest.Message(
                            role: $0.role.rawValue,
                            content: stripModeMarkers($0.content)
                        )
                    }
                )
            )
        } catch {
            completion(.failure(error))
            return
        }

        httpClient.data(for: request) { [decoder] result in
            switch result {
            case .success(let data):
                do {
                    let response = try decoder.decode(ChatCompletionResponse.self, from: data)
                    completion(.success(response.firstContent))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func addAuthHeader(to request: inout URLRequest) {
        guard let token = config.token, token.isEmpty == false else {
            return
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func modelForRequest(
        requestedModel: String,
        hasImageModeMarker: Bool,
        hasVideoModeMarker: Bool
    ) -> String {
        if hasImageModeMarker {
            return "glm-image"
        }
        if hasVideoModeMarker {
            return "cogvideox-3"
        }
        if requestedModel.caseInsensitiveCompare("glm-image") == .orderedSame ||
            requestedModel.caseInsensitiveCompare("cogvideox-3") == .orderedSame {
            return AppConfig.defaultChatModel
        }
        return requestedModel
    }

    private func stripModeMarkers(_ content: String) -> String {
        content
            .replacingOccurrences(of: imageModeMarker, with: "")
            .replacingOccurrences(of: videoModeMarker, with: "")
            .replacingOccurrences(of: documentModeMarker, with: "")
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension URL {
    var normalizedGatewayURL: URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if components.path.isEmpty == false {
            components.path = "/" + components.path
        }
        components.query = nil
        components.fragment = nil
        return components.url ?? self
    }
}
