import Combine
import Foundation

final class AvatarViewModel: ObservableObject {
    @Published var draft: String = ""
    @Published private(set) var turns: [AvatarConversationTurn] = []
    @Published private(set) var mood: AvatarMood = .idle
    @Published private(set) var motion: AvatarMotion = .idle
    @Published private(set) var isListening = false
    @Published private(set) var isThinking = false
    @Published private(set) var isSpeaking = false
    @Published var errorMessage: String?
    @Published private(set) var highlightedTurnID: String?
    @Published private(set) var highlightedSpeechRange: NSRange?
    @Published var showUpgrade = false
    @Published var showAIDataSharingConsent = false

    private let gatewayClient: GatewayClient
    private let speechRecognizer = AvatarSpeechRecognizer()
    private let speechSynthesizer = AvatarSpeechSynthesizer()
    let digitalHuman = DuixDigitalHumanController.shared
    private var generation = 0
    private let preferences = AppPreferences()
    private let freeConversationLimit = 3
    private let greetings = [
        "你好，我是 Lily，很高兴认识你。",
        "嗨，见到你真开心，今天想聊点什么？",
        "你好呀，我一直在这里等你。",
        "欢迎回来，我是你的数字人伙伴 Lily。",
        "很高兴和你见面，有什么可以帮你的吗？",
        "嗨，我是 Lily，愿你今天有个好心情。",
        "你好，轻松一点，我们慢慢聊。",
        "见到你真好，我已经准备好听你说啦。",
        "你好呀，今天也让我陪在你身边吧。",
        "嗨，朋友，又到了我们打招呼的时间。"
    ]

    init(gatewayClient: GatewayClient) {
        self.gatewayClient = gatewayClient
        let savedTurns = preferences.avatarConversationHistory
        turns = savedTurns.isEmpty ? [AvatarConversationTurn(
                role: .assistant,
                content: "你好，我是你的智能体助手。你可以直接说话，也可以输入文字。"
            )] : savedTurns
        // Migrate conversations created before the dedicated trial counter existed.
        if preferences.avatarFreeConversationCount == 0 {
            preferences.avatarFreeConversationCount = min(
                freeConversationLimit,
                savedTurns.filter { $0.role == .user }.count
            )
        }
    }

    var statusText: String {
        if isListening { return "正在聆听你的语音" }
        if isThinking { return "正在组织回答" }
        if isSpeaking { return "正在播报回答" }
        return "点击麦克风开始对话"
    }

    var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    var canPlayGreeting: Bool {
        !isListening && !isThinking && !isSpeaking
    }

    func toggleListening() {
        if isListening {
            stopListeningAndSubmit()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard !isThinking else { return }
        stopSpeaking()
        errorMessage = nil

        speechRecognizer.requestAuthorization { [weak self] granted, message in
            guard let self = self else { return }
            guard granted else {
                self.setError(message ?? "语音识别未授权")
                return
            }
            self.isListening = true
            self.setAvatarState(mood: .listening, motion: .listen)
            self.speechRecognizer.start { [weak self] text in
                DispatchQueue.main.async {
                    self?.draft = text
                }
            } onError: { [weak self] message in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.isListening {
                        self.setError("语音识别失败：\(message)")
                    }
                }
            }
        }
    }

    func stopListeningAndSubmit() {
        guard isListening else { return }
        speechRecognizer.stop()
        isListening = false
        submitDraft()
    }

    func submitDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else {
            if !isThinking {
                setAvatarState(mood: .idle, motion: .idle)
            }
            return
        }

        guard preferences.hasAIDataSharingConsent else {
            showAIDataSharingConsent = true
            return
        }

        let hasActiveMembership = preferences.isLoggedIn && preferences.isVipActive
        guard hasActiveMembership || preferences.avatarFreeConversationCount < freeConversationLimit else {
            showUpgrade = true
            return
        }

        draft = ""
        errorMessage = nil
        stopSpeaking()

        let userTurn = AvatarConversationTurn(role: .user, content: text)
        turns.append(userTurn)
        if !hasActiveMembership {
            preferences.avatarFreeConversationCount += 1
        }
        persistConversation()
        isThinking = true
        setAvatarState(mood: .thinking, motion: .think)

        generation &+= 1
        let currentGeneration = generation
        let requestMessages = buildRequestMessages()

        gatewayClient.sendChat(messages: requestMessages) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, currentGeneration == self.generation else { return }
                self.isThinking = false
                switch result {
                case .success(let reply):
                    let cleanReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                    let content = cleanReply.isEmpty ? "我暂时没有拿到有效回答，请稍后再试。" : cleanReply
                    #if DEBUG
                    let preview = content.replacingOccurrences(of: "\n", with: " ").prefix(80)
                    print("Duix text response chars=\(content.count) preview=\(preview)")
                    #endif
                    let assistantTurn = AvatarConversationTurn(role: .assistant, content: content)
                    self.turns.append(assistantTurn)
                    self.persistConversation()
                    self.speak(self.speechText(for: content), turnID: assistantTurn.id, displayText: content)
                case .failure(let error):
                    self.setError(self.friendlyErrorMessage(error))
                }
            }
        }
    }

    func agreeToAIDataSharingAndSubmit() {
        preferences.grantAIDataSharingConsent()
        showAIDataSharingConsent = false
        submitDraft()
    }

    func declineAIDataSharing() {
        showAIDataSharingConsent = false
        if !isListening && !isThinking && !isSpeaking {
            setAvatarState(mood: .idle, motion: .idle)
        }
    }

    func stopAll() {
        generation &+= 1
        speechRecognizer.stop()
        stopSpeaking()
        isListening = false
        isThinking = false
        setAvatarState(mood: .idle, motion: .idle)
    }

    func stopSpeaking() {
        speechSynthesizer.stop()
        isSpeaking = false
        highlightedTurnID = nil
        highlightedSpeechRange = nil
        if !isThinking && !isListening {
            setAvatarState(mood: .idle, motion: .idle)
        }
    }

    func playRandomGreeting() {
        guard canPlayGreeting else { return }
        let greeting = greetings.randomElement() ?? greetings[0]
        speak(greeting)
    }

    func readAloud(_ turn: AvatarConversationTurn) {
        guard !isThinking, !isListening else { return }
        let content = turn.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        speak(speechText(for: content), turnID: turn.id, displayText: turn.content)
    }

    private func persistConversation() {
        preferences.avatarConversationHistory = turns
    }

    private func speak(_ text: String, turnID: String? = nil, displayText: String? = nil) {
        let spokenText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spokenText.isEmpty else {
            isSpeaking = false
            setAvatarState(mood: .idle, motion: .idle)
            return
        }
        highlightedTurnID = turnID
        highlightedSpeechRange = nil
        let originalDisplayText = displayText ?? spokenText
        var displaySearchLocation = 0
        speechSynthesizer.speak(spokenText, digitalHuman: digitalHuman) { [weak self] in
            DispatchQueue.main.async {
                self?.isSpeaking = true
                self?.setAvatarState(mood: .speaking, motion: .talk)
            }
        } onFinish: { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSpeaking = false
                self.highlightedTurnID = nil
                self.highlightedSpeechRange = nil
                if !self.isThinking && !self.isListening {
                    self.setAvatarState(mood: .happy, motion: .nod)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        guard let self = self, !self.isThinking, !self.isListening, !self.isSpeaking else { return }
                        self.setAvatarState(mood: .idle, motion: .idle)
                    }
                }
            }
        } onRangeChange: { [weak self] range in
            guard let self = self, self.highlightedTurnID == turnID else { return }
            self.highlightedSpeechRange = self.mapSpeechRange(
                range,
                spokenText: spokenText,
                displayText: originalDisplayText,
                searchLocation: &displaySearchLocation
            )
        }
    }

    private func mapSpeechRange(
        _ range: NSRange,
        spokenText: String,
        displayText: String,
        searchLocation: inout Int
    ) -> NSRange? {
        let spokenNSString = spokenText as NSString
        guard range.location != NSNotFound, NSMaxRange(range) <= spokenNSString.length else { return nil }
        let fragment = spokenNSString.substring(with: range)
        guard !fragment.isEmpty else { return nil }

        let displayNSString = displayText as NSString
        let remainingLength = max(0, displayNSString.length - searchLocation)
        var match = displayNSString.range(
            of: fragment,
            options: [],
            range: NSRange(location: searchLocation, length: remainingLength)
        )
        if match.location == NSNotFound {
            match = displayNSString.range(of: fragment)
        }
        guard match.location != NSNotFound else { return nil }
        searchLocation = NSMaxRange(match)
        return match
    }

    private func speechText(for content: String) -> String {
        var text = content
        text = text.replacingOccurrences(
            of: #"(?s)```.*?```"#,
            with: "这里生成了一段代码或文件内容，已显示在对话中。",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\!\[[^\]]*\]\([^)]+\)"#,
            with: "这里生成了一张图片。",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\[[^\]]+\]\([^)]+\)"#,
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"https?://\S+"#,
            with: "",
            options: .regularExpression
        )
        let markdownCharacters = CharacterSet(charactersIn: "#>*_`~-")
        text = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: markdownCharacters.union(.whitespaces)) }
            .filter { !$0.isEmpty }
            .joined(separator: "。")
        if text.count > 700 {
            text = String(text.prefix(700)) + "。后面的内容已显示在对话中。"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildRequestMessages() -> [ChatMessage] {
        let system = ChatMessage(
            role: .system,
            content: "你是 AgentClaw 的拟人智能体助手。请用自然、口语化、简洁的中文回答，适合被语音播报。"
        )
        let recent = turns.suffix(12).map { turn in
            ChatMessage(role: turn.role, content: turn.content)
        }
        return [system] + recent
    }

    private func setAvatarState(mood: AvatarMood, motion: AvatarMotion) {
        self.mood = mood
        self.motion = motion
    }

    private func setError(_ message: String) {
        errorMessage = message
        isListening = false
        isThinking = false
        isSpeaking = false
        setAvatarState(mood: .error, motion: .idle)
    }

    private func friendlyErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return error.localizedDescription
        }
        switch nsError.code {
        case NSURLErrorTimedOut:
            return "网络超时了，请稍后重试"
        case NSURLErrorNotConnectedToInternet:
            return "当前没有网络，请检查连接"
        case NSURLErrorNetworkConnectionLost:
            return "网络连接中断了，请再试一次"
        case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return "暂时连不上智能体服务，请检查 Gateway 设置"
        default:
            return "请求失败：\(error.localizedDescription)"
        }
    }
}
