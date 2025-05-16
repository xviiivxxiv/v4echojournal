import Foundation

/// Represents a message in the chat history, mirroring OpenAI API structure.
struct ChatMessage: Codable, Hashable, Identifiable {
    // Define the role enum matching OpenAI API
    enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let content: String
    
    // Optional convenience initializer if needed elsewhere
    // init(role: Role, content: String) {
    //     self.role = role
    //     self.content = content
    // }
}
 