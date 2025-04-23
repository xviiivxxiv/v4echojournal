import Foundation

// MARK: - OpenAI API Chat Completion Structures

/// Represents the overall structure of a successful chat completion response.
public struct OpenAIChatResponse: Codable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [Choice]
    // Optional: let usage: Usage?
}

/// Represents a single choice/completion within the response.
public struct Choice: Codable {
    public let index: Int?
    public let message: Message
    public let finish_reason: String?
}

/// Represents the message content (question or answer) from the assistant or user.
public struct Message: Codable {
    public let role: String // "assistant", "user", "system"
    public let content: String
}

// MARK: - Optional Usage Info (if needed from OpenAI)
/*
public struct Usage: Codable {
    public let prompt_tokens: Int
    public let completion_tokens: Int
    public let total_tokens: Int
}
*/

// MARK: - OpenAI API Error Structures

/// Represents the structure of an error response from the OpenAI API.
public struct OpenAIErrorResponse: Codable {
    public let error: OpenAIErrorDetail
}

/// Contains the details of an API error.
public struct OpenAIErrorDetail: Codable {
    public let message: String
    public let type: String
    public let param: String?
    public let code: String?
}

