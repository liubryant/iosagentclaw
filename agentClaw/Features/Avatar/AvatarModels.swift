import Foundation

enum AvatarMood: Equatable {
    case idle
    case listening
    case thinking
    case speaking
    case happy
    case error

    var title: String {
        switch self {
        case .idle: return "待命"
        case .listening: return "聆听"
        case .thinking: return "思考"
        case .speaking: return "讲述"
        case .happy: return "完成"
        case .error: return "异常"
        }
    }
}

enum AvatarMotion: Equatable {
    case idle
    case listen
    case think
    case talk
    case nod
    case wave

    var title: String {
        switch self {
        case .idle: return "自然待机"
        case .listen: return "倾听"
        case .think: return "思考"
        case .talk: return "口型联动"
        case .nod: return "点头"
        case .wave: return "招手"
        }
    }
}

struct AvatarConversationTurn: Identifiable, Equatable, Codable {
    let id: String
    let role: ChatRole
    let content: String
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        role: ChatRole,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
