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

    // Add an internal computed property to check configuration status
    internal var isClientConfigured: Bool {
        return openAIClient != nil
    }

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

    // MARK: - Keyword Extraction
    func extractKeywords(from text: String, count: Int) async throws -> [String] {
        guard let token = self.openAIClient?.configuration.token else {
            print("❌ GPTService: Token missing for keyword extraction.")
            throw GPTError.setupError("OpenAI client or token not initialized for keyword extraction.")
        }

        print("▶️ GPTService calling extractKeywords (Restored - Dynamic Data)")

        let apiEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: apiEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Keep 30s timeout

        let prompt = """
        Extract the \(count) most relevant and concise keywords or short phrases from the following journal entry.
        The keywords should capture the main topics or themes.
        Return them as a comma-separated list. Do not include numbering or any other text before or after the list.
        Journal Entry:
        \'\'\'
        \(text) // CORRECTED: Using the actual input text with single backslash for interpolation
        \'\'\'
        Keywords:
        """
        print("  GPTService: [Keyword Extraction] Generated prompt: \(prompt)")

        let messagesPayload = [
            ChatMessagePayload(role: "user", content: prompt)
        ]

        let requestBody = ChatCompletionRequestBody(
            model: "gpt-4-turbo-preview",
            messages: messagesPayload,
            max_tokens: 50,
            temperature: 0.2
        )

        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("  GPTService: [Keyword Extraction] Dynamically generated Request body JSON: \(jsonString)")
            } else {
                print("  GPTService: [Keyword Extraction] Could not convert dynamic request body jsonData to string.")
            }
        } catch let encodingError {
            print("❌ GPTService: [Keyword Extraction] JSONEncoding error for dynamic request body: \(encodingError.localizedDescription)")
            throw GPTError.messageEncodingFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            print("  GPTService: [Keyword Extraction] Preparing URLSessionDataTask (Dynamic Data)...")
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                print("  GPTService: [Keyword Extraction] URLSessionDataTask completion handler invoked (Dynamic Data).")

                if let error = error {
                    print("❌ GPTService: Keyword extraction URLSessionDataTask error (Dynamic Data): \(error.localizedDescription)")
                    if (error as NSError).code == NSURLErrorTimedOut {
                        print("  GPTService: Specific timeout error NSURLErrorTimedOut detected (Dynamic Data).")
                    }
                    continuation.resume(throwing: GPTError.requestFailed(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                    print("❌ GPTService: Keyword extraction invalid response or no data from URLSessionDataTask (Dynamic Data).")
                    continuation.resume(throwing: GPTError.invalidResponse)
                    return
                }
                
                let responseBodyForLogging = String(data: data, encoding: .utf8) ?? "Could not decode response body"
                print("  GPTService: [Keyword Extraction] URLSessionDataTask HTTP status (Dynamic Data): \(httpResponse.statusCode). Body: \(responseBodyForLogging)")

                guard httpResponse.statusCode == 200 else {
                    continuation.resume(throwing: GPTError.invalidResponse) 
                    return
                }
                
                do {
                    let decodedResponse = try JSONDecoder().decode(FlexibleChatCompletionResponse.self, from: data)
                    guard let firstChoice = decodedResponse.choices.first, let content = firstChoice.message.content else {
                        print("❌ GPTService: Invalid response structure or missing content for keywords (Dynamic Data).")
                        continuation.resume(throwing: GPTError.invalidResponse)
                        return
                    }
                    
                    print("  GPTService: Raw keyword response content (Dynamic Data): '\(content)'")
                    let keywords = content
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    
                    continuation.resume(returning: Array(keywords.prefix(count)))

                } catch let decodingError {
                    print("❌ GPTService: Decoding error for keyword extraction (Dynamic Data): \(decodingError)")
                    continuation.resume(throwing: GPTError.invalidResponse)
                }
            }
            print("  GPTService: [Keyword Extraction] Starting URLSessionDataTask (task.resume()) (Dynamic Data)...")
            task.resume()
        }
    }

    // MARK: - Assess Emotions from Text
    func assessEmotions(from text: String, emotionCategories: [String: [String]]) async throws -> [(name: String, category: String)] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ GPTService: Cannot assess emotions from empty text.")
            return []
        }
        guard let client = openAIClient, let token = client.configuration.token else {
            throw GPTError.setupError("OpenAI client or token not initialized for emotion assessment.")
        }

        print("▶️ GPTService calling assessEmotions.")

        let apiEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: apiEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45 // Slightly longer timeout for potentially deeper analysis

        // Construct the emotion list for the prompt
        var emotionPromptList = ""
        for (category, emotions) in emotionCategories {
            emotionPromptList += "\nCategory: \(category)\nEmotions: \(emotions.joined(separator: ", "))\n"
        }

        let prompt = """
        Analyze the following journal entry and identify up to 2-3 primary emotions the user seems to be expressing or implying, even if not stated explicitly.
        Choose these emotions *only* from the provided list of categorized emotions.
        For each identified emotion, return its name and its category exactly as provided in the list.
        Format your response as a JSON array of objects, where each object has a "name" (string) and a "category" (string) key. For example: [{"name": "Joyful", "category": "Great"}, {"name": "Anxious", "category": "Bad"}]
        If no strong emotions from the list are clearly identifiable, return an empty JSON array [].

        Provided Emotion Categories and Emotions:
        \(emotionPromptList)

        Journal Entry:
        \'\'\'
        \(text)
        \'\'\'

        Identified Emotions (JSON Array):
        """
        print("  GPTService: [Emotion Assessment] Generated prompt - (see verbose logs for full prompt if needed).") // Prompt can be long
        // For debugging, you might want to print the full prompt, but be mindful of console limits.
        // print("  GPTService: [Emotion Assessment] Full Prompt:\n\(prompt)") 

        let messagesPayload = [ChatMessagePayload(role: "user", content: prompt)]
        let requestBody = ChatCompletionRequestBody(
            model: "gpt-4-turbo-preview", // Using GPT-4 for emotion assessment
            messages: messagesPayload,
            max_tokens: 150, // Max tokens for a few emotion objects in JSON format
            temperature: 0.3 // Lower temperature for more factual identification from list
        )

        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
        } catch let encodingError {
            print("❌ GPTService: [Emotion Assessment] JSONEncoding error: \(encodingError.localizedDescription)")
            throw GPTError.messageEncodingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            print("  GPTService: [Emotion Assessment] Preparing URLSessionDataTask...")
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                print("  GPTService: [Emotion Assessment] URLSessionDataTask completion handler invoked.")
                if let error = error {
                    print("❌ GPTService: [Emotion Assessment] URLSessionDataTask error: \(error.localizedDescription)")
                    continuation.resume(throwing: GPTError.requestFailed(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                    print("❌ GPTService: [Emotion Assessment] Invalid response or no data.")
                    continuation.resume(throwing: GPTError.invalidResponse)
                    return
                }
                let responseBodyForLogging = String(data: data, encoding: .utf8) ?? "Could not decode response body"
                print("  GPTService: [Emotion Assessment] HTTP status: \(httpResponse.statusCode). Body: \(responseBodyForLogging)")
                guard httpResponse.statusCode == 200 else {
                    continuation.resume(throwing: GPTError.invalidResponse)
                    return
                }
                do {
                    // Attempt to parse the full response first to get the message content
                    let fullDecodedResponse = try JSONDecoder().decode(FlexibleChatCompletionResponse.self, from: data)
                    guard let messageContent = fullDecodedResponse.choices.first?.message.content else {
                        print("❌ GPTService: [Emotion Assessment] Could not extract message content from GPT response.")
                        continuation.resume(returning: [])
                        return
                    }
                    
                    print("  GPTService: [Emotion Assessment] Extracted message content: \(messageContent)")

                    // Now, clean and parse the JSON array from within this message content
                    var jsonString = messageContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Remove potential Markdown code block fences
                    if jsonString.hasPrefix("```json") {
                        jsonString = String(jsonString.dropFirst(7))
                    }
                    if jsonString.hasPrefix("```") { // If only ``` was used
                        jsonString = String(jsonString.dropFirst(3))
                    }
                    if jsonString.hasSuffix("```") {
                        jsonString = String(jsonString.dropLast(3))
                    }
                    jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines) // Trim again after removing fences

                    print("  GPTService: [Emotion Assessment] Cleaned JSON string for parsing: \(jsonString)")

                    struct EmotionResponse: Decodable {
                        let name: String
                        let category: String
                    }
                    
                    if jsonString.starts(with: "[") && jsonString.hasSuffix("]") && !jsonString.isEmpty {
                        if let jsonDataToParse = jsonString.data(using: .utf8) {
                            let decodedEmotions = try JSONDecoder().decode([EmotionResponse].self, from: jsonDataToParse)
                            let result = decodedEmotions.map { (name: $0.name, category: $0.category) }
                            print("  GPTService: [Emotion Assessment] Decoded emotions: \(result)")
                            continuation.resume(returning: result)
                        } else {
                             print("❌ GPTService: [Emotion Assessment] Could not convert cleaned JSON string to Data.")
                             continuation.resume(returning: [])
                        }
                    } else if jsonString.isEmpty || jsonString == "[]" {
                        print("  GPTService: [Emotion Assessment] Received empty array or effectively empty content, indicating no emotions identified.")
                        continuation.resume(returning: [])
                    } else {
                        print("❌ GPTService: [Emotion Assessment] Content is not a valid JSON array string after cleaning: '\(jsonString)'")
                        continuation.resume(returning: []) // If still not a JSON array, return empty
                    }
                } catch let decodingError {
                    print("❌ GPTService: [Emotion Assessment] Decoding error: \(decodingError). Response was: \(responseBodyForLogging)")
                    continuation.resume(returning: [])
                }
            }
            print("  GPTService: [Emotion Assessment] Starting URLSessionDataTask...")
            task.resume()
        }
    }

    // MARK: - Generate Headline from Keywords
    func generateHeadline(fromKeywords keywords: [String]) async throws -> String {
        guard !keywords.isEmpty else {
            print("⚠️ GPTService: Cannot generate headline from empty keywords array.")
            return "" // Or throw an error, or return a default placeholder
        }
        guard let client = openAIClient, let token = client.configuration.token else {
            throw GPTError.setupError("OpenAI client or token not initialized for headline generation.")
        }

        print("▶️ GPTService calling generateHeadline with keywords: \(keywords.joined(separator: ", "))")

        let apiEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: apiEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20 // 20 seconds timeout for headline generation

        let keywordList = keywords.joined(separator: ", ")
        let prompt = """
        Based on the following keywords from a journal entry: "\(keywordList)".
        Create a concise, engaging, and reflective headline or title (max 10-12 words) suitable for this journal entry.
        The headline should sound like a natural journal entry title, not just a list of keywords.
        Do not include any quotation marks in your response, just the headline text itself.
        Headline:
        """
        print("  GPTService: [Headline Generation] Generated prompt: \(prompt)")

        let messagesPayload = [ChatMessagePayload(role: "user", content: prompt)]
        let requestBody = ChatCompletionRequestBody(
            model: "gpt-3.5-turbo", // Using GPT-3.5 Turbo for speed and cost for headlines
            messages: messagesPayload,
            max_tokens: 60, // Max tokens for a headline
            temperature: 0.7 // Slightly higher temperature for more creative headlines
        )

        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
        } catch let encodingError {
            print("❌ GPTService: [Headline Generation] JSONEncoding error: \(encodingError.localizedDescription)")
            throw GPTError.messageEncodingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            print("  GPTService: [Headline Generation] Preparing URLSessionDataTask...")
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                print("  GPTService: [Headline Generation] URLSessionDataTask completion handler invoked.")
                if let error = error {
                    print("❌ GPTService: [Headline Generation] URLSessionDataTask error: \(error.localizedDescription)")
                    continuation.resume(throwing: GPTError.requestFailed(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                    print("❌ GPTService: [Headline Generation] Invalid response or no data.")
                    continuation.resume(throwing: GPTError.invalidResponse)
                    return
                }
                let responseBodyForLogging = String(data: data, encoding: .utf8) ?? "Could not decode response body"
                print("  GPTService: [Headline Generation] HTTP status: \(httpResponse.statusCode). Body: \(responseBodyForLogging)")
                guard httpResponse.statusCode == 200 else {
                    continuation.resume(throwing: GPTError.invalidResponse)
                    return
                }
                do {
                    let decodedResponse = try JSONDecoder().decode(FlexibleChatCompletionResponse.self, from: data)
                    guard let firstChoice = decodedResponse.choices.first, let content = firstChoice.message.content else {
                        print("❌ GPTService: [Headline Generation] Invalid response structure or missing content.")
                        continuation.resume(throwing: GPTError.invalidResponse)
                        return
                    }
                    let headline = content.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))
                    print("  GPTService: [Headline Generation] Raw headline response: '\(content)', Trimmed headline: '\(headline)'")
                    continuation.resume(returning: headline)
                } catch let decodingError {
                    print("❌ GPTService: [Headline Generation] Decoding error: \(decodingError)")
                    continuation.resume(throwing: GPTError.invalidResponse)
                }
            }
            print("  GPTService: [Headline Generation] Starting URLSessionDataTask...")
            task.resume()
        }
    }

    // MARK: - Generate AI Summary
    func generateSummary(for text: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ GPTService: Cannot generate summary from empty text.")
            return "" // Or throw an appropriate error
        }
        guard let client = openAIClient, let token = client.configuration.token else {
            throw GPTError.setupError("OpenAI client or token not initialized for summary generation.")
        }

        print("▶️ GPTService calling generateSummary.")

        let apiEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: apiEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45 // Timeout for summary generation, can be adjusted

        let newPrompt = """
        Analyze the following journal entry, which includes user thoughts and AI interactions. Generate a very brief and snappy summary.
        Start with one single, concise sentence (around 15-25 words) that captures the absolute core essence of the entry.
        Then, provide 2-3 extremely concise bullet points (max 5-10 words each) highlighting only the most critical topics or feelings.
        The entire summary should be very short and easy to read at a glance.

        Format:
        [Core essence sentence]
        • [Short bullet 1]
        • [Short bullet 2]
        • [Optional short bullet 3]

        Journal Entry:
        '''
        \(text)
        '''

        Snappy Summary:
        """
        // print("  GPTService: [Summary Generation] Generated prompt (first 100 chars): \(String(prompt.prefix(100)))..." )
        // Use newPrompt instead of prompt
        print("  GPTService: [Summary Generation] Generated prompt (first 100 chars): \(String(newPrompt.prefix(100)))..." )

        let messagesPayload = [ChatMessagePayload(role: "user", content: newPrompt)] // Use newPrompt
        let requestBody = ChatCompletionRequestBody(
            model: "gpt-4-turbo-preview", // Or "gpt-4-turbo"
            messages: messagesPayload,
            max_tokens: 250, // Adjusted for a sentence and 3-5 bullet points
            temperature: 0.6  // Balanced temperature for informative yet natural summary
        )

        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
        } catch let encodingError {
            print("❌ GPTService: [Summary Generation] JSONEncoding error: \(encodingError.localizedDescription)")
            throw GPTError.messageEncodingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            print("  GPTService: [Summary Generation] Preparing URLSessionDataTask...")
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                print("  GPTService: [Summary Generation] URLSessionDataTask completion handler invoked.")
                if let error = error {
                    print("❌ GPTService: [Summary Generation] URLSessionDataTask error: \(error.localizedDescription)")
                    continuation.resume(throwing: GPTError.requestFailed(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                    print("❌ GPTService: [Summary Generation] Invalid response or no data.")
                    continuation.resume(throwing: GPTError.invalidResponse)
                    return
                }
                let responseBodyForLogging = String(data: data, encoding: .utf8) ?? "Could not decode response body"
                print("  GPTService: [Summary Generation] HTTP status: \(httpResponse.statusCode). Body (first 200 chars): \(String(responseBodyForLogging.prefix(200)))..." )
                
                guard httpResponse.statusCode == 200 else {
                    print("❌ GPTService: [Summary Generation] Non-200 HTTP status: \(httpResponse.statusCode)." )
                    continuation.resume(throwing: GPTError.invalidResponse)
                    return
                }
                
                do {
                    let decodedResponse = try JSONDecoder().decode(FlexibleChatCompletionResponse.self, from: data)
                    guard let firstChoice = decodedResponse.choices.first, let content = firstChoice.message.content else {
                        print("❌ GPTService: [Summary Generation] Invalid response structure or missing content.")
                        continuation.resume(throwing: GPTError.invalidResponse)
                        return
                    }
                    let summary = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("  GPTService: [Summary Generation] Raw summary response: '\(summary)'")
                    if summary.isEmpty {
                        print("⚠️ GPTService: [Summary Generation] Received empty summary from API.")
                         continuation.resume(returning: "") // Return empty string if API gives empty
                    } else {
                        continuation.resume(returning: summary)
                    }
                } catch let decodingError {
                    print("❌ GPTService: [Summary Generation] Decoding error: \(decodingError)")
                    continuation.resume(throwing: GPTError.invalidResponse)
                }
            }
            print("  GPTService: [Summary Generation] Starting URLSessionDataTask...")
            task.resume()
        }
    }
}
