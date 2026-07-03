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
    /// 每次发送自增；用于在生成期间切换/新建对话后作废“在途”的回复，避免落到别的对话里。
    private var sendGeneration = 0

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

    /// 中断当前生成：作废在途回复并结束加载态。
    /// 用于生成期间切换/新建对话时，先停止当前生成再切走（与安卓 abortCurrent 一致）。
    func cancelGeneration() {
        guard isSending else { return }
        sendGeneration &+= 1
        isSending = false
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

        // 记录本次生成所属的对话与代次；若期间被取消或切换到别的对话，回复将被丢弃。
        sendGeneration &+= 1
        let generation = sendGeneration
        let targetSessionID = selectedSessionID

        let handleResult: (Result<String, Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                // 已被取消/切换：作废在途结果，避免落入其它对话
                guard generation == self.sendGeneration else {
                    return
                }
                switch result {
                case .success(let reply):
                    let fallbackTitle = self.sessions.first(where: { $0.id == targetSessionID })?.title ?? "document"
                    let saveResult = self.generatedDocumentStore.saveGeneratedDocuments(
                        from: reply,
                        fallbackTitle: fallbackTitle
                    )
                    self.append(ChatMessage(
                        role: .assistant,
                        content: saveResult.displayContent,
                        generatedDocuments: saveResult.documents
                    ), to: targetSessionID)
                case .failure(let error):
                    self.errorMessage = self.friendlyErrorMessage(error)
                }
                self.isSending = false
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

    /// 把底层网络错误（尤其是「the request timed out」超时）转成更友好的中文提示。
    /// 后端返回的业务错误（HTTP 状态码 + 报文）仍保留原文，便于用户理解具体原因。
    private func friendlyErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return error.localizedDescription
        }
        switch nsError.code {
        case NSURLErrorTimedOut:
            return "网络有点慢，这次生成超时了，请稍后重试～"
        case NSURLErrorNotConnectedToInternet:
            return "似乎没有网络，请检查网络连接后重试"
        case NSURLErrorNetworkConnectionLost:
            return "网络连接中断了，请稍后重试"
        case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return "暂时连不上服务器，请稍后再试"
        case NSURLErrorCancelled:
            return "本次生成已取消"
        default:
            return "网络似乎不太稳定，请稍后重试"
        }
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
        append(message, to: selectedSessionID)
    }

    private func append(_ message: ChatMessage, to sessionID: String) {
        var next = messagesBySession[sessionID] ?? []
        next.append(message)
        messagesBySession[sessionID] = next
        touchSession(sessionID)
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
        touchSession(selectedSessionID)
    }

    private func touchSession(_ sessionID: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
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
