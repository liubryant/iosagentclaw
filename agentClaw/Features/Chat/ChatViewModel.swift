import Combine
import Foundation
import UIKit

final class ChatViewModel: ObservableObject {
    @Published private(set) var sessions: [LocalChatSession]
    @Published var selectedSessionID: String
    @Published var draft: String = ""
    @Published private(set) var isSending = false
    @Published var errorMessage: String?
    @Published var attachedImages: [UIImage] = []

    private let gatewayClient: GatewayClient
    private let preferences: AppPreferences
    let generatedDocumentStore: GeneratedDocumentStore
    private var messagesBySession: [String: [ChatMessage]] = [:]
    private var entryModesBySession: [String: ChatEntryMode] = [:]

    init(
        gatewayClient: GatewayClient,
        preferences: AppPreferences,
        generatedDocumentStore: GeneratedDocumentStore = GeneratedDocumentStore()
    ) {
        self.gatewayClient = gatewayClient
        self.preferences = preferences
        self.generatedDocumentStore = generatedDocumentStore

        if let snapshot = preferences.chatHistorySnapshot,
           snapshot.sessions.isEmpty == false {
            self.sessions = snapshot.sessions
            self.selectedSessionID = snapshot.sessions.contains(where: { $0.id == snapshot.selectedSessionID })
                ? snapshot.selectedSessionID
                : snapshot.sessions[0].id
            self.messagesBySession = snapshot.messagesBySession
            self.entryModesBySession = snapshot.entryModesBySession
            snapshot.sessions.forEach { session in
                if self.messagesBySession[session.id] == nil {
                    self.messagesBySession[session.id] = []
                }
                if self.entryModesBySession[session.id] == nil {
                    self.entryModesBySession[session.id] = .default
                }
            }
        } else {
            let initialSession = LocalChatSession(title: "新对话")
            self.sessions = [initialSession]
            self.selectedSessionID = initialSession.id
            self.messagesBySession[initialSession.id] = []
            self.entryModesBySession[initialSession.id] = .default
            saveHistory()
        }
    }

    var messages: [ChatMessage] {
        messagesBySession[selectedSessionID] ?? []
    }

    var allDocuments: [GeneratedDocument] {
        let messageFiles = messagesBySession.values.flatMap { messages in
            messages.flatMap { $0.generatedDocuments }
        }
        var seen = Set<String>()
        return (generatedDocumentStore.allExportedFiles() + messageFiles).filter {
            seen.insert($0.relativePath).inserted
        }
    }

    var selectedSession: LocalChatSession? {
        sessions.first { $0.id == selectedSessionID }
    }

    var selectedEntryMode: ChatEntryMode {
        entryModesBySession[selectedSessionID] ?? .default
    }

    func saveGeneratedVideo(
        from url: URL,
        completion: @escaping (Result<GeneratedDocument, Error>) -> Void
    ) {
        generatedDocumentStore.downloadAndSaveMedia(
            from: url,
            defaultPrefix: "generated-video",
            mimeType: "video/mp4"
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if case .success = result {
                    self.objectWillChange.send()
                }
                completion(result)
            }
        }
    }

    func createSession(entryMode: ChatEntryMode = .default) {
        let session = LocalChatSession()
        sessions = [session] + sessions
        selectedSessionID = session.id
        messagesBySession[session.id] = []
        entryModesBySession[session.id] = entryMode
        draft = ""
        errorMessage = nil
        saveHistory()
    }

    func createSession(withDraft draft: String, entryMode: ChatEntryMode = .default) {
        createSession(entryMode: entryMode)
        self.draft = draft
    }

    /// 切换到纯文本模式：清除当前 session 的图文/视频选中状态，并清除已附加的图片。
    /// 用于点击"今日热点"等场景——不创建新对话，只重置输入区状态。
    func resetToDefaultMode() {
        entryModesBySession[selectedSessionID] = .default
        attachedImages = []
        saveHistory()
        objectWillChange.send()
    }

    func selectSession(_ session: LocalChatSession) {
        selectedSessionID = session.id
        draft = ""
        errorMessage = nil
        saveHistory()
        objectWillChange.send()
    }

    func deleteSession(_ session: LocalChatSession) {
        guard sessions.count > 1 else {
            messagesBySession[session.id] = []
            saveHistory()
            objectWillChange.send()
            return
        }

        sessions = sessions.filter { $0.id != session.id }
        messagesBySession.removeValue(forKey: session.id)
        entryModesBySession.removeValue(forKey: session.id)
        if selectedSessionID == session.id {
            selectedSessionID = sessions[0].id
        }
        saveHistory()
        objectWillChange.send()
    }

    func attachImage(_ image: UIImage) {
        attachedImages.append(image)
    }

    func removeAttachedImage(at index: Int) {
        guard attachedImages.indices.contains(index) else { return }
        attachedImages.remove(at: index)
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = attachedImages
        let entryMode = selectedEntryMode
        guard (text.isEmpty == false || images.isEmpty == false), isSending == false else {
            return
        }

        draft = ""
        attachedImages = []
        errorMessage = nil
        let displayText = text.isEmpty ? "发送了\(images.count)张图片" : text
        let userMessage = ChatMessage(
            role: .user,
            content: displayText,
            attachedImageData: images.compactMap(chatPreviewData)
        )
        append(userMessage)
        updateSelectedSessionTitleIfNeeded(displayText)
        saveHistory()
        isSending = true

        let handleResult: (Result<String, Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let reply):
                    guard let self = self else {
                        return
                    }
                    let saveResult = self.generatedDocumentStore.saveGeneratedDocuments(
                        from: reply,
                        fallbackTitle: self.selectedSession?.title ?? "document"
                    )
                    self.append(ChatMessage(
                        role: .assistant,
                        content: saveResult.displayContent,
                        generatedDocuments: saveResult.documents
                    ))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
                self?.isSending = false
            }
        }

        // 视频生成是异步任务：直接提交 /videos/generations 并轮询结果，
        // 与 Android 保持一致，避免 chat/completions 只返回任务提交状态。
        if entryMode == .video {
            gatewayClient.generateVideo(prompt: text, completion: handleResult)
            return
        }

        // 与 Android 保持一致：图片模式携带源图时使用独立图生图接口，
        // 不再落入 glm-image 的文生图聊天请求。
        if entryMode == .image, let sourceImage = images.first {
            guard let imageData = sourceImage.jpegData(compressionQuality: 0.75) else {
                handleResult(.failure(NSError(
                    domain: "ChatViewModel.ImageEdit",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "所选图片无法处理，请重新选择"]
                )))
                return
            }
            let editPrompt = text.isEmpty ? "基于这张图片生成一张新图片" : text
            gatewayClient.editImage(
                prompt: editPrompt,
                imageBase64: imageData.base64EncodedString(),
                completion: handleResult
            )
            return
        }

        let outbound = outboundContent(for: text, images: images, entryMode: entryMode)
        let requestMessages = messages.map { message -> ChatMessage in
            guard message.id == userMessage.id else {
                return message
            }
            var outboundMessage = message
            outboundMessage.content = outbound
            return outboundMessage
        }
        gatewayClient.sendChat(messages: requestMessages, completion: handleResult)
    }

    private func outboundContent(for text: String, images: [UIImage] = [], entryMode: ChatEntryMode) -> String {
        let imageParts: [String] = images.compactMap { img in
            guard let data = img.jpegData(compressionQuality: 0.75) else { return nil }
            return "![图片](data:image/jpeg;base64,\(data.base64EncodedString()))"
        }
        switch entryMode {
        case .image:
            let parts = imageParts + (text.isEmpty ? [] : [text])
            return "[[IMAGE_MODE]] " + parts.joined(separator: "\n")
        case .video:
            let parts = imageParts + (text.isEmpty ? [] : [text])
            return "[[VIDEO_MODE]] " + parts.joined(separator: "\n")
        case .default:
            if shouldRequestDocumentFile(for: text) {
                return "[[DOCUMENT_MODE]] \(documentGenerationInstruction)\n\n用户需求：\(text)"
            }
            if imageParts.isEmpty { return text }
            return (imageParts + (text.isEmpty ? [] : [text])).joined(separator: "\n")
        }
    }

    private func chatPreviewData(for image: UIImage) -> Data? {
        let maxDimension: CGFloat = 800
        let originalSize = image.size
        let scale = min(maxDimension / max(originalSize.width, originalSize.height), 1)
        let preview: UIImage

        if scale < 1 {
            let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 1)
            image.draw(in: CGRect(origin: .zero, size: targetSize))
            preview = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            preview = image
        }
        return preview.jpegData(compressionQuality: 0.68)
    }

    private var documentGenerationInstruction: String {
        """
        你正在为 iOS 客户端生成可导出的文档文件。
        当用户要求生成文档、报告、文章、Markdown、HTML、README 或文件时，必须把最终文件内容放进代码块，不要只在聊天里输出正文。
        如果用户没有指定格式，默认生成 HTML。
        文件内容控制在适合手机预览的长度，优先完整、简洁、可打开，不要输出超长正文。
        格式必须是：
        ```file path="文件名.html"
        <!doctype html>
        ...
        ```
        或：
        ```file path="文件名.md"
        # Markdown 内容
        ```
        代码块外只保留一句简短说明。
        """
    }

    private func shouldRequestDocumentFile(for text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = [
            "文档", "报告", "简报", "文章", "文件", "导出",
            "html", "markdown", ".md", "md文件", "readme",
            "document", "report", "file"
        ]
        return keywords.contains { lower.contains($0) }
    }

    private func append(_ message: ChatMessage) {
        var next = messagesBySession[selectedSessionID] ?? []
        next.append(message)
        messagesBySession[selectedSessionID] = next
        touchSelectedSession()
        saveHistory()
        objectWillChange.send()
    }

    private func updateSelectedSessionTitleIfNeeded(_ text: String) {
        guard let index = sessions.firstIndex(where: { $0.id == selectedSessionID }) else {
            return
        }
        var nextSessions = sessions
        if sessions[index].title == "新对话" {
            nextSessions[index].title = text.count > 18 ? String(text.prefix(18)) + "..." : text
        }
        nextSessions[index].updatedAt = Date()
        sessions = nextSessions
    }

    private func touchSelectedSession() {
        guard let index = sessions.firstIndex(where: { $0.id == selectedSessionID }) else {
            return
        }
        var nextSessions = sessions
        nextSessions[index].updatedAt = Date()
        sessions = nextSessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func saveHistory() {
        preferences.chatHistorySnapshot = ChatHistorySnapshot(
            sessions: sessions,
            selectedSessionID: selectedSessionID,
            messagesBySession: messagesBySession,
            entryModesBySession: entryModesBySession
        )
    }

    func clearAllData() {
        // 重置为初始状态
        let initialSession = LocalChatSession(title: "新对话")
        self.sessions = [initialSession]
        self.selectedSessionID = initialSession.id
        self.messagesBySession = [initialSession.id: []]
        self.entryModesBySession = [initialSession.id: .default]
        self.draft = ""
        self.errorMessage = nil

        // 清除持久化数据
        preferences.chatHistorySnapshot = nil

        // 通知视图更新
        objectWillChange.send()
    }
}
