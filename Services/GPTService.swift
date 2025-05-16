import Foundation
import OpenAI

// MARK: - Sanity-Protected API Key Loader
/*
func getAPIKey(named keyName: String) -> String? {
    #if DEBUG
    print("⚠️ getAPIKey() called in DEBUG — returning nil to force hardcoded fallback.")
    return nil
    #else
    fatalError("🚨 getAPIKey() called in production — this should never happen! Use a secure injection strategy.")
    #endif
}
*/

enum GPTError: Error, LocalizedError {
    case apiKeyMissing
    case requestFailed(Error)
    case invalidResponse
    case setupError(String)
    case messageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Missing OpenAI API Key. Please check configuration."
        case .requestFailed(let underlyingError):
            return "OpenAI request failed: \(underlyingError.localizedDescription)"
        case .invalidResponse:
            return "Invalid response received from OpenAI API."
        case .setupError(let message):
            return "GPTService setup error: \(message)"
        case .messageEncodingFailed:
            return "Failed to encode message for OpenAI API."
        }
    }
}

// MARK: - Custom Decodable Structs for OpenAI Response
// Define structs mirroring OpenAI's response, but with optional fingerprint
struct FlexibleChatCompletionResponse: Decodable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [FlexibleChoice]
    let usage: Usage?
    let system_fingerprint: String? // The key field, now optional
}

struct FlexibleChoice: Decodable {
    let index: Int?
    let message: FlexibleMessage
    // Add other fields like finish_reason if needed, make them optional
    let finish_reason: String?
}

struct FlexibleMessage: Decodable {
    let role: String?
    let content: String?
}

// Usage struct might be needed if present in the response
struct Usage: Decodable {
    let prompt_tokens: Int?
    let completion_tokens: Int?
    let total_tokens: Int?
}

// MARK: - Request Body Structs (Encodable)
private struct ChatMessagePayload: Encodable {
    let role: String
    let content: String
}

private struct ChatCompletionRequestBody: Encodable {
    let model: String
    let messages: [ChatMessagePayload]
    let max_tokens: Int
    let temperature: Double
}

final class GPTService {

    static let shared = GPTService()

    private let openAIClient: OpenAI?

    // MARK: - API Key Retrieval (Using Info.plist)
    // Make this static so it can be called before self is initialized
    private static func getGptAPIKey() -> String? {
         print("▶️ GPTService: getGptAPIKey() called.")
        let correctKeyName = "OpenAI_API_Key" // Corrected Case
        
        // --- Enhanced Debug Logging --- 
        if let infoDict = Bundle.main.infoDictionary {
            print("  GPTService: Info.plist keys found: \(infoDict.keys)")
            if let rawValue = infoDict[correctKeyName] {
                print("  GPTService: Raw value for \(correctKeyName): \(rawValue) (Type: \(type(of: rawValue)))")
            } else {
                print("  GPTService: Key '\(correctKeyName)' NOT FOUND in infoDictionary.")
            }
        } else {
            print("  GPTService: Could not load infoDictionary from Bundle.main")
        }
        // --- End Enhanced Debug Logging ---
        
        // Use the correct key name variable
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: correctKeyName) as? String else {
            print("❌ GPTService: Failed to get API key '\(correctKeyName)' from Info.plist (guard check failed)")
            return nil
        }
        
             if apiKey.starts(with: "sk-") && apiKey.count > 50 {
            print("✅ GPTService: Found valid API Key from Info.plist")
                 return apiKey
             } else {
            print("⚠️ GPTService: API Key from Info.plist appears invalid (format/length)")
             return nil
         }
    }

    // Private init using ConfigLoader
    private init() {
        print("▶️ GPTService: init() called.")
        // Call the static method using the class name
        if let apiKey = GPTService.getGptAPIKey() {
            let config = OpenAI.Configuration(token: apiKey, host: "api.openai.com")
            self.openAIClient = OpenAI(configuration: config)
            let tokenPrefix = apiKey.prefix(10)
            let tokenSuffix = apiKey.suffix(4)
            print("✅ GPTService: OpenAI client configured using key from Info.plist [\(tokenPrefix)...\(tokenSuffix)].")
        } else {
            self.openAIClient = nil
            print("❌ GPTService: Failed to get API key during init via Info.plist. Client not configured.")
        }
        print("🏁 GPTService initialization sequence finished.")
    }

    // MARK: - Generate Follow-Up Questions (Multi)
    func generateFollowUps(from entry: String) async throws -> [String] {
        guard let client = openAIClient else {
            throw GPTError.setupError("OpenAI client not initialized.")
        }

        // 🧪 Safely print masked API key used at runtime
        let tokenPrefix = client.configuration.token?.prefix(10) ?? "nil"
        let tokenSuffix = client.configuration.token?.suffix(4) ?? "nil"
        print("🧪 GPTService (multi) using API Key: \(tokenPrefix)...\(tokenSuffix)")

        let prompt = "I just journaled: \"\(entry)\". Ask me 2–3 thoughtful follow-up questions to help me reflect further. Keep them short and emotionally intelligent."

        let messages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: "You are a helpful journaling assistant."),
            .init(role: .user, content: prompt)
        ].compactMap { $0 }

        let query = ChatQuery(messages: messages, model: .gpt4)

        do {
            let result = try await client.chats(query: query)
            guard let firstChoice = result.choices.first else {
                throw GPTError.invalidResponse
            }

            let content = firstChoice.message.content ?? ""
            let questions = content
                .split(whereSeparator: { $0.isNewline })
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return questions.map { question in
                if let match = question.range(of: "^\\\\s*[0-9]+\\\\.?\\\\s*", options: String.CompareOptions.regularExpression) {
                    return String(question[match.upperBound...]).trimmingCharacters(in: CharacterSet.whitespaces)
                }
                return question
            }

        } catch {
            throw GPTError.requestFailed(error)
        }
    }

    // MARK: - Single Follow-Up (from history) - MANUAL REQUEST
    func generateFollowUp(history: [ChatMessage]) async throws -> String {
        guard let client = openAIClient, let token = client.configuration.token else {
            throw GPTError.setupError("OpenAI client or token not initialized.")
        }

        print("▶️ GPTService calling generateFollowUp with key starting: \(token.prefix(10))...\(token.suffix(4))")

        // --- Manual URLSession Request --- 
        let apiEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: apiEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare messages for JSON body
        let systemMessageContent = """
        You are a reflective journaling assistant designed to act like the user's future self, a trusted best friend, or a wise grandparent — someone who knows how to gently ask the right question at the right time to help the user reflect more deeply.
        Your job is to ask only one open-ended follow-up question at a time, based solely on what the user just said in their journal entry or response. Your tone should be warm, curious, and non-judgmental — like a soft voice in the user's head helping them unpack what they're feeling and why.
        Every question should:
        Be deeply relevant to what the user just shared (no randomness or generic prompts)

        Encourage emotional honesty, self-discovery, or introspection

        Help the user explore how an experience made them feel, what it meant to them, or what they learned

        Avoid summarizing or responding — just ask a single, thoughtfully chosen question

        Reflect the idea that these entries might one day be read or listened to by their future self

        Examples of good follow-up angles include:
        "What part of that experience stuck with you the most?"

        "Why do you think that moment impacted you more than others?"

        "What do you wish you could say to yourself in that moment?"

        "If this happened again, how would you want to show up differently?"

        If the user seems to be reaching a natural conclusion in their entry, it's okay to gently signal the end with a wrap-up style question like:
        "Is there anything else you need to let out before we close this chapter?"

        "Would your future self understand how you felt today, or is there more to share?"

        Pick only the best possible question based on where they are in the conversation — as if you only had one chance to help them go a layer deeper.
        """
        // Re-add force-unwrap: ensure systemMsgParam is non-optional
        let systemMsgParam = ChatQuery.ChatCompletionMessageParam(role: .system, content: systemMessageContent)!
        let historyParams: [ChatQuery.ChatCompletionMessageParam] = history.compactMap { msg in
             let role: ChatQuery.ChatCompletionMessageParam.Role = (msg.role == .user) ? .user : .assistant
             return .init(role: role, content: msg.content)
        }
        
        // Explicitly type the combined array before mapping
        let combinedParams: [ChatQuery.ChatCompletionMessageParam] = [systemMsgParam] + historyParams
        
        // Convert to our Encodable payload struct by mapping the explicitly typed array
        let messagesPayload = combinedParams.map { param -> ChatMessagePayload in
            // Attempt to get string value directly from the Content enum/struct
            var textContent = ""
            if let contentValue = param.content { // Safely unwrap the Content?
                 // Try converting/interpolating the content value directly to String
                 textContent = "\(contentValue)" 
                 // Alternatively, if it's RawRepresentable<String>: textContent = contentValue.rawValue ?? ""
            }
            return ChatMessagePayload(role: param.role.rawValue, content: textContent)
        }

        // Create request body using Encodable struct
        let requestBody = ChatCompletionRequestBody(
            model: "gpt-4-turbo",
            messages: messagesPayload,
            max_tokens: 60,
            temperature: 0.75
        )

        // --- Log Request Body --- 
        print("💡 Sending Request Body to OpenAI:")
        // Attempt to pretty-print JSON for readability
        if let jsonData = try? JSONEncoder().encode(requestBody), 
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
           let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyJsonString = String(data: prettyJsonData, encoding: .utf8) {
            print(prettyJsonString)
        } else {
             print("  (Could not pretty-print JSON body)")
             print(requestBody) // Print the dictionary directly if pretty-printing fails
        }
        // --- End Log ---

        // Encode the request body using JSONEncoder
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(requestBody)
        } catch {
             print("❌ Error encoding request body: \(error)")
             throw GPTError.messageEncodingFailed
        }

        // Perform request and decode with flexible struct
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP Response received.")
                throw GPTError.invalidResponse
            }

            print("  generateFollowUp: Received HTTP status code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorString = String(data: responseData, encoding: .utf8) ?? "Unknown API error"
                print("❌ generateFollowUp: API Error (\(httpResponse.statusCode)): \(errorString)")
                // Consider wrapping this in GPTError.requestFailed or a new specific error
                throw NSError(domain: "OpenAIAPIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorString])
            }
            
            // --- Log Raw Response Data ---
            if let jsonString = String(data: responseData, encoding: .utf8) {
                print("💡 Raw OpenAI Response JSON (Status 200): \(jsonString)")
            } else {
                print("⚠️ Could not convert response data to string.")
            }
            // --- End Log ---
            
            // Decode using *our* flexible response struct
            let decodedResponse = try JSONDecoder().decode(FlexibleChatCompletionResponse.self, from: responseData)
            
            // Allow empty content, but ensure the optional chain succeeded
            guard let content = decodedResponse.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                print("❌ Could not extract content from flexible response (nil value encountered).")
                throw GPTError.invalidResponse
            }
            
            // Log if the content is empty, but don't throw error
            if content.isEmpty {
                 print("⚠️ Extracted content from flexible response is an empty string.")
            }
            
            print("💬 Extracted content from flexible response: \(content)")
            return content

        } catch let error as DecodingError {
            print("💥 Decoding Error during chat completion: \(error)")
            // Log details for debugging
             let nsError = error as NSError
             print("  Error Domain: \(nsError.domain)")
             print("  Error Code: \(nsError.code)")
             print("  Error UserInfo: \(nsError.userInfo)")
             print("  Decoding Context: \(error.localizedDescription)") 
            throw GPTError.invalidResponse // Treat as invalid response
        } catch {
            print("💥 Unexpected error during manual chat completion: \(error)")
            throw GPTError.requestFailed(error)
        }
        // --- End Manual URLSession Request ---
    }

    // MARK: - Process Journal Entry (from GPTService 2 - SDK Version)
    // Added this method from GPTService 2
    func processJournalEntry(_ entry: String, previousContext: String = "") async throws -> String {
         print("▶️ processJournalEntry called.")
         guard let client = openAIClient else {
             print("❌ processJournalEntry: OpenAI client not configured (API Key missing on init?).")
             throw GPTError.setupError("OpenAI client not initialized.")
         }

         print("  processJournalEntry: Using API Key for request (from client config).")

        // Construct the messages for the API call using compactMap and qualified roles
        let baseMessages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: "You are a helpful journaling assistant. Analyze the provided journal entry and the optional previous context (summary of prior entries). Identify key themes, emotions, and insights. Respond concisely, perhaps with bullet points or a short summary, focusing on reflective observations rather than generic advice. If previous context is provided, try to link the current entry to it."),
            .init(role: .user, content: "Current entry: \\(entry)")
        ].compactMap { $0 } // Use compactMap

        // Include previous context only if it's not empty
        var allMessages = baseMessages
        if !previousContext.isEmpty {
            if let contextMessage = ChatQuery.ChatCompletionMessageParam(role: .user, content: "Previous context: \\(previousContext)") {
                allMessages.insert(contextMessage, at: 1)
            }
        }

        // Create the chat query - Reorder parameters
        let query = ChatQuery(messages: allMessages, model: .gpt4)

        print("  processJournalEntry: Sending request to OpenAI via SDK...")

        do {
            let result = try await client.chats(query: query)
            if let firstChoice = result.choices.first {
                 let responseContent = firstChoice.message.content ?? "No response content."
                  print("✅ processJournalEntry: Received successful response from OpenAI.")
                 return responseContent
            } else {
                 print("⚠️ processJournalEntry: OpenAI response contained no choices.")
                 throw GPTError.invalidResponse
            }
        } catch let error as OpenAIError {
            print("❌ processJournalEntry: OpenAI SDK Request failed: \(error.localizedDescription)")
            throw GPTError.requestFailed(error)
        } catch {
            print("❌ processJournalEntry: Unexpected Request failed: \(error.localizedDescription)")
            throw GPTError.requestFailed(error)
        }
    }
}
