import Combine
import Foundation

final class ChatViewModel: ObservableObject {
    @Published private(set) var sessions: [LocalChatSession]
    @Published var selectedSessionID: String
    @Published var draft: String = ""
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

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
        messagesBySession.values.flatMap { messages in
            messages.flatMap { $0.generatedDocuments }
        }
    }

    var selectedSession: LocalChatSession? {
        sessions.first { $0.id == selectedSessionID }
    }

    var selectedEntryMode: ChatEntryMode {
        entryModesBySession[selectedSessionID] ?? .default
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

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false, isSending == false else {
            return
        }

        draft = ""
        errorMessage = nil
        let userMessage = ChatMessage(role: .user, content: text)
        append(userMessage)
        updateSelectedSessionTitleIfNeeded(text)
        saveHistory()
        isSending = true

        let requestMessages = messages.map { message -> ChatMessage in
            guard message.id == userMessage.id else {
                return message
            }
            var outboundMessage = message
            outboundMessage.content = outboundContent(for: text, entryMode: selectedEntryMode)
            return outboundMessage
        }
        gatewayClient.sendChat(messages: requestMessages) { [weak self] result in
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
    }

    private func outboundContent(for text: String, entryMode: ChatEntryMode) -> String {
        switch entryMode {
        case .image:
            return "[[OPENCLAW_IMAGE_MODE]] \(text)"
        case .video:
            return "[[OPENCLAW_VIDEO_MODE]] \(text)"
        case .default:
            if shouldRequestDocumentFile(for: text) {
                return "[[OPENCLAW_DOCUMENT_MODE]] \(documentGenerationInstruction)\n\n用户需求：\(text)"
            }
            return text
        }
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
