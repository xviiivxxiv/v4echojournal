import Foundation
import OpenAI // Import the package

// Function to read the API key from Info.plist
func getAPIKey(named keyName: String) -> String? {
    // Check main bundle first
    if let key = Bundle.main.object(forInfoDictionaryKey: keyName) as? String, !key.isEmpty {
        // Handle potential issue from malformed plist key tag
        // If the key contains newlines from the bad tag, try splitting and taking the first line
        let components = key.split(separator: "\n")
        if let firstComponent = components.first, !firstComponent.isEmpty {
             print("API Key found in main bundle Info.plist")
            return String(firstComponent)
        }
    }
    // Add fallbacks if necessary (e.g., environment variables)
    print("Warning: API Key '\(keyName)' not found or empty in main bundle Info.plist.")
    return nil
}

enum GPTError: Error {
    case apiKeyMissing
    case requestFailed(Error)
    case invalidResponse
    case setupError(String)
    case messageEncodingFailed
}

class GPTService {

    private let openAIClient: OpenAI?

    init() {
        // Read the API key from Info.plist
        guard let apiKey = getAPIKey(named: "OpenAI_API_Key") else {
            print("ERROR: OpenAI API Key named 'OpenAI_API_Key' is missing or invalid in Info.plist")
            self.openAIClient = nil
            return
        }

        // Initialize the OpenAI client
        let config = OpenAI.Configuration(token: apiKey)
        self.openAIClient = OpenAI(configuration: config)
        print("GPTService initialized successfully.")
    }

    func generateFollowUps(from entry: String) async throws -> [String] {
        // Ensure client was initialized successfully
        guard let client = openAIClient else {
            throw GPTError.setupError("OpenAI client not initialized. Check API Key.")
        }

        let prompt = "I just journaled: \"\(entry)\". Ask me 2–3 thoughtful follow-up questions to help me reflect further. Keep them short and emotionally intelligent."

        // Use guard let to safely unwrap the potentially failable initializer
        guard let userMessage = ChatQuery.ChatCompletionMessageParam(role: .user, content: prompt) else {
            print("Error: Failed to create ChatCompletionMessageParam from prompt.")
            throw GPTError.messageEncodingFailed
        }

        // Use the chat query structure for newer models, passing the unwrapped message in an array
        let query = ChatQuery(
            messages: [userMessage],
            model: .gpt4 // Ensure model is explicitly GPT-4
            // Add other parameters like temperature, max_tokens if needed
        )

        print("--- Calling OpenAI API ---")
        print("Prompt: \(prompt)")

        do {
            let result = try await client.chats(query: query)
            guard let firstChoice = result.choices.first else {
                print("Error: No choices received from OpenAI.")
                throw GPTError.invalidResponse
            }

            // Handle optional content safely
            let content = firstChoice.message.content ?? ""
            print("Raw response content: \(content)")

            // Split response into potential questions (often newline-separated)
            // Use explicit closure for clarity
            let questions = content.split { (character: Character) -> Bool in
                character.isNewline
            }
                                  .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                                  .filter { !$0.isEmpty }

            // Clean up potential numbering (e.g., "1. Question?")
            let cleanedQuestions = questions.map { question -> String in
                if let match = question.range(of: "^\\s*[0-9]+\\.?\\s*", options: String.CompareOptions.regularExpression) {
                    return String(question[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
                return question
            }

            print("Returning cleaned questions: \(cleanedQuestions)")
            return cleanedQuestions

        } catch {
            print("Error calling OpenAI API: \(error)")
            // Check for specific OpenAIError types if needed
            if let openAIError = error as? OpenAIError {
                print("OpenAI Specific Error: \(openAIError.localizedDescription)")
                // Handle specific errors like authentication, rate limits, etc.
                 throw GPTError.requestFailed(openAIError)
            } else {
                 throw GPTError.requestFailed(error)
            }
        }
    }
} 
