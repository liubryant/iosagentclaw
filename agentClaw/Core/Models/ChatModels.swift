import Foundation

enum ChatRole: String, Codable {
    case system
    case user
    case assistant
    case tool
}

enum ChatEntryMode: String, Codable, Equatable {
    case `default`
    case image
    case video
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    var role: ChatRole
    var content: String
    var createdAt: Date
    var generatedDocuments: [GeneratedDocument]

    init(
        id: String = UUID().uuidString,
        role: ChatRole,
        content: String,
        createdAt: Date = Date(),
        generatedDocuments: [GeneratedDocument] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.generatedDocuments = generatedDocuments
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case createdAt
        case generatedDocuments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        role = try container.decode(ChatRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        generatedDocuments = try container.decodeIfPresent([GeneratedDocument].self, forKey: .generatedDocuments) ?? []
    }
}

struct GeneratedDocument: Identifiable, Codable, Equatable {
    let id: String
    let displayName: String
    let relativePath: String
    let mimeType: String
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        displayName: String,
        relativePath: String,
        mimeType: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.relativePath = relativePath
        self.mimeType = mimeType
        self.createdAt = createdAt
    }
}

struct LocalChatSession: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String = "新对话",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
    }
}

struct ChatHistorySnapshot: Codable, Equatable {
    var sessions: [LocalChatSession]
    var selectedSessionID: String
    var messagesBySession: [String: [ChatMessage]]
    var entryModesBySession: [String: ChatEntryMode]

    init(
        sessions: [LocalChatSession],
        selectedSessionID: String,
        messagesBySession: [String: [ChatMessage]],
        entryModesBySession: [String: ChatEntryMode] = [:]
    ) {
        self.sessions = sessions
        self.selectedSessionID = selectedSessionID
        self.messagesBySession = messagesBySession
        self.entryModesBySession = entryModesBySession
    }

    private enum CodingKeys: String, CodingKey {
        case sessions
        case selectedSessionID
        case messagesBySession
        case entryModesBySession
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessions = try container.decode([LocalChatSession].self, forKey: .sessions)
        selectedSessionID = try container.decode(String.self, forKey: .selectedSessionID)
        messagesBySession = try container.decode([String: [ChatMessage]].self, forKey: .messagesBySession)
        entryModesBySession = try container.decodeIfPresent([String: ChatEntryMode].self, forKey: .entryModesBySession) ?? [:]
    }
}

struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let stream: Bool
    let responseMode: String?
    let messages: [Message]
}

struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String?
            let content: String?
        }

        let message: Message?
    }

    let choices: [Choice]

    var firstContent: String {
        choices.first?.message?.content ?? ""
    }
}
