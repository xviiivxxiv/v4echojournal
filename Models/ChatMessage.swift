import Foundation

// Represents a message in the chat history for GPT context
struct ChatMessage: Codable, Hashable {
    enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    let role: Role
    let content: String

    // Optional convenience initializer
    init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}
