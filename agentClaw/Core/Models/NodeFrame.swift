import Foundation

struct NodeFrame: Codable, Equatable, Identifiable {
    var id: String?
    var method: String?
    var event: String?
    var payload: [String: JSONValue]?
    var error: [String: JSONValue]?

    var isResponse: Bool {
        id != nil && method == nil && event == nil
    }

    var isEvent: Bool {
        event != nil
    }
}

