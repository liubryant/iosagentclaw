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
        guard ensureAIDataSharingConsent(completion: completion) else { return }
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

    func editImage(
        prompt: String,
        imageBase64: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard ensureAIDataSharingConsent(completion: completion) else { return }
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty, !imageBase64.isEmpty else {
            completion(.failure(NSError(
                domain: "GatewayClient.ImageEdit",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "请选择图片并输入编辑描述"]
            )))
            return
        }

        let url = config.baseURL.normalizedGatewayURL
            .appendingPathComponent("images")
            .appendingPathComponent("edits")
        var request = URLRequest(url: url, timeoutInterval: AppConfig.mediaGenerationRequestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "prompt": cleanPrompt,
                "image": "data:image/jpeg;base64,\(imageBase64)"
            ])
        } catch {
            completion(.failure(error))
            return
        }

        httpClient.data(for: request) { result in
            switch result {
            case .success(let data):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let imageURL = Self.firstGeneratedImageURL(in: json)
                    else {
                        throw NSError(
                            domain: "GatewayClient.ImageEdit",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "图片生成完成，但未返回可展示的图片地址"]
                        )
                    }
                    completion(.success("已为你生成图片。\n\n提示词：\(cleanPrompt)\n\n图片链接1: \(imageURL)"))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func generateVideo(
        prompt: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard ensureAIDataSharingConsent(completion: completion) else { return }
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else {
            completion(.failure(mediaError("视频描述不能为空")))
            return
        }

        let url = config.baseURL.normalizedGatewayURL
            .appendingPathComponent("videos")
            .appendingPathComponent("generations")
        var request = URLRequest(url: url, timeoutInterval: AppConfig.mediaGenerationRequestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": "cogvideox-3",
                "prompt": cleanPrompt,
                "quality": "speed",
                "with_audio": false,
                "size": "1280x720",
                "fps": 30
            ])
        } catch {
            completion(.failure(error))
            return
        }

        httpClient.data(for: request) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                do {
                    let json = try Self.decodeJSONObject(data)
                    if let output = Self.videoOutput(in: json) {
                        completion(.success(Self.videoMessage(prompt: cleanPrompt, taskID: nil, output: output)))
                        return
                    }
                    guard let taskID = Self.stringValue(for: "id", in: json), !taskID.isEmpty else {
                        completion(.failure(self.mediaError("视频任务提交失败：未返回任务 ID")))
                        return
                    }
                    self.pollVideo(
                        taskID: taskID,
                        prompt: cleanPrompt,
                        deadline: Date().addingTimeInterval(150),
                        completion: completion
                    )
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func pollVideo(
        taskID: String,
        prompt: String,
        deadline: Date,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard Date() <= deadline else {
            completion(.failure(mediaError("视频生成时间较长，请稍后再试。任务ID：\(taskID)")))
            return
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self else { return }
            let url = self.config.baseURL.normalizedGatewayURL
                .appendingPathComponent("videos")
                .appendingPathComponent("generations")
                .appendingPathComponent(taskID)
            var request = URLRequest(url: url, timeoutInterval: AppConfig.mediaGenerationRequestTimeout)
            request.httpMethod = "GET"
            self.addAuthHeader(to: &request)

            self.httpClient.data(for: request) { result in
                switch result {
                case .success(let data):
                    do {
                        let json = try Self.decodeJSONObject(data)
                        if let output = Self.videoOutput(in: json) {
                            completion(.success(Self.videoMessage(prompt: prompt, taskID: taskID, output: output)))
                            return
                        }
                        let status = Self.stringValue(for: "task_status", in: json)?.uppercased()
                            ?? Self.stringValue(for: "status", in: json)?.uppercased()
                            ?? "PROCESSING"
                        #if DEBUG
                        print("video_poll taskID=\(taskID) status=\(status) keys=\(json.keys.sorted())")
                        #endif
                        if ["FAIL", "FAILED", "CANCELED", "CANCELLED"].contains(status) {
                            completion(.failure(self.mediaError("视频生成失败：\(status)")))
                            return
                        }
                        if ["SUCCESS", "SUCCEEDED", "COMPLETED"].contains(status) {
                            completion(.failure(self.mediaError("视频任务已完成，但服务端未返回视频地址。任务ID：\(taskID)")))
                            return
                        }
                        self.pollVideo(taskID: taskID, prompt: prompt, deadline: deadline, completion: completion)
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    @discardableResult
    private func ensureAIDataSharingConsent<T>(
        completion: @escaping (Result<T, Error>) -> Void
    ) -> Bool {
        guard preferences.hasAIDataSharingConsent else {
            completion(.failure(NSError(
                domain: "GatewayClient.AIDataSharingConsent",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "请先同意第三方AI服务数据共享授权"]
            )))
            return false
        }
        return true
    }

    private struct VideoOutput {
        let url: String
        let coverURL: String?
    }

    private static func decodeJSONObject(_ data: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "GatewayClient.Media",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "视频接口返回格式不是 JSON"]
            )
        }
        return json
    }

    private static func payload(in json: [String: Any]) -> [String: Any] {
        (json["data"] as? [String: Any]) ?? json
    }

    private static func stringValue(for key: String, in json: [String: Any]) -> String? {
        let value = payload(in: json)[key]
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func videoOutput(in json: [String: Any]) -> VideoOutput? {
        let root = payload(in: json)
        for key in ["video_result", "videos", "results", "output", "data"] {
            if let results = root[key] as? [[String: Any]] {
                for result in results {
                    if let output = videoOutput(inItem: result) { return output }
                }
            }
            if let result = root[key] as? [String: Any],
               let output = videoOutput(inItem: result) {
                return output
            }
            if let urls = root[key] as? [String], let url = urls.first(where: { !$0.isEmpty }) {
                return VideoOutput(url: url, coverURL: nil)
            }
        }

        if let output = videoOutput(inItem: root) { return output }

        if let choices = root["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let videos = message["videos"] as? [[String: Any]] {
            for video in videos {
                if let videoURL = video["video_url"] as? [String: Any],
                   let url = videoURL["url"] as? String,
                   !url.isEmpty {
                    return VideoOutput(url: url, coverURL: nil)
                }
            }
        }
        return nil
    }

    private static func videoOutput(inItem item: [String: Any]) -> VideoOutput? {
        let coverURL = item["cover_image_url"] as? String
            ?? item["coverImageUrl"] as? String
            ?? item["cover_url"] as? String
        for key in ["url", "video_url", "videoUrl", "play_url", "playUrl"] {
            if let url = item[key] as? String, !url.isEmpty {
                return VideoOutput(url: url, coverURL: coverURL)
            }
            if let nested = item[key] as? [String: Any],
               let url = nested["url"] as? String,
               !url.isEmpty {
                return VideoOutput(url: url, coverURL: coverURL)
            }
        }
        return nil
    }

    private static func videoMessage(prompt: String, taskID: String?, output: VideoOutput) -> String {
        var lines = ["已为你生成视频。", "", "提示词：\(prompt)"]
        if let taskID = taskID { lines += ["", "任务ID：\(taskID)"] }
        if let coverURL = output.coverURL, !coverURL.isEmpty { lines += ["", "视频封面: \(coverURL)"] }
        lines += ["", "视频链接1: \(output.url)"]
        return lines.joined(separator: "\n")
    }

    private func mediaError(_ message: String) -> Error {
        NSError(
            domain: "GatewayClient.Media",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private static func firstGeneratedImageURL(in json: [String: Any]) -> String? {
        for key in ["data", "images"] {
            if let items = json[key] as? [[String: Any]],
               let url = items.compactMap({ $0["url"] as? String }).first(where: { !$0.isEmpty }) {
                return url
            }
        }

        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let images = message["images"] as? [[String: Any]] {
            for image in images {
                if let imageURL = image["image_url"] as? [String: Any],
                   let url = imageURL["url"] as? String,
                   !url.isEmpty {
                    return url
                }
            }
        }
        return nil
    }

    private func addAuthHeader(to request: inout URLRequest) {
        // 鉴权优先级：
        // 1) 用户在「网关设置」里手动填写的自定义 token（高级用法，普通用户不会有）；
        // 2) 登录后拿到的用户 access token —— 与后端 VIP / 鉴权同源（同一 host），
        //    普通用户登录即可用它调用生成接口，无需再手动配置网关 token。
        // 之前只认自定义网关 token，导致普通用户/审核设备生成时缺少 Authorization 头而报错。
        let token = config.token?.nilIfEmptyToken
            ?? preferences.userAccessToken?.nilIfEmptyToken
        guard let token = token else {
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

private extension String {
    var nilIfEmptyToken: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
