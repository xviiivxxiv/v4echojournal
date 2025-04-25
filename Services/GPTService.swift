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

enum GPTError: Error {
    case apiKeyMissingOrInvalid
    case requestFailed(Error)
    case invalidResponse
    case setupError(String)
    case messageEncodingFailed
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

final class GPTService {

    static let shared = GPTService()

    private let openAIClient: OpenAI?

    // Make init private to enforce singleton pattern
    private init() {
        var apiKey: String? = nil
        var keySource: String = "Unknown"

        // 1. Try loading from Environment Variable (Highest Priority)
        if let keyFromEnv = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !keyFromEnv.isEmpty,
           !keyFromEnv.starts(with: "YOUR_") {
            // Trim whitespace just in case
            apiKey = keyFromEnv.trimmingCharacters(in: .whitespacesAndNewlines)
            keySource = "Environment Variable"
            print("🔑 GPTService: Found valid API Key in Environment Variable")
        }

        // 2. Try loading from Info.plist (Fallback 1)
        if apiKey == nil { // Only check if env var failed
            if let infoDict = Bundle.main.infoDictionary,
               let keyFromInfoPlist = infoDict["OpenAI_API_Key"] as? String,
               !keyFromInfoPlist.isEmpty,
               !keyFromInfoPlist.starts(with: "YOUR_") {
                // Trim whitespace just in case
                apiKey = keyFromInfoPlist.trimmingCharacters(in: .whitespacesAndNewlines)
                keySource = "Info.plist"
                print("🔑 GPTService: Found valid API Key in Info.plist")
            } else {
                print("ℹ️ GPTService: Info.plist key invalid, missing, or placeholder.")
            }
        }

        // 3. Fallback to hardcoded key ONLY in DEBUG if other methods fail
        #if DEBUG
        if apiKey == nil {
            print("⚠️ GPTService DEBUG: No fallback key provided. Ensure Env Var or Info.plist is set.")
            // apiKey = "YOUR_DEBUG_FALLBACK_KEY_HERE" // REMOVED HARDCODED KEY
            // keySource = "Hardcoded (DEBUG)"
        }
        #endif

        // 4. Initialize OpenAI client if a key was found
        if let finalKey = apiKey {
             let tokenPrefix = finalKey.prefix(10)
             let tokenSuffix = finalKey.suffix(4)
             print("🧠 GPTService INIT: Attempting to use key from [\(keySource)] starting with \(tokenPrefix)...\(tokenSuffix)")
             let config = OpenAI.Configuration(token: finalKey)
             self.openAIClient = OpenAI(configuration: config)
             print("✅ GPTService OpenAI client configured.")
        } else {
            print("❌ GPTService INIT FAILED: No valid API Key found from any source.")
            self.openAIClient = nil
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

        guard let userMessage = ChatQuery.ChatCompletionMessageParam(role: .user, content: prompt) else {
            throw GPTError.messageEncodingFailed
        }

        let query = ChatQuery(messages: [userMessage], model: .gpt4)

        do {
            let result = try await client.chats(query: query)
            guard let firstChoice = result.choices.first else {
                throw GPTError.invalidResponse
            }

            let content = firstChoice.message.content ?? ""
            let questions = content
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return questions.map { question in
                if let match = question.range(of: "^\\s*[0-9]+\\.?\\s*", options: .regularExpression) {
                    return String(question[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
                return question
            }

        } catch {
            throw GPTError.requestFailed(error)
        }
    }

    // MARK: - Single Follow-Up (from history) - MANUAL REQUEST
    func generateFollowUp(history: [ChatMessage]) async throws -> String {
        // Still need the client for configuration details like token
        guard let client = openAIClient, let token = client.configuration.token else {
            throw GPTError.setupError("OpenAI client or token not initialized.")
        }

        print("▶️ GPTService calling generateFollowUp MANUALLY with key starting: \(token.prefix(10))...\(token.suffix(4))")

        // Define the updated system prompt
        let systemPrompt = ["role": "system", "content": """
        You are a reflective journaling assistant designed to act like the user's future self, a trusted best friend, or a wise grandparent — someone who knows how to gently ask the right question at the right time to help the user reflect more deeply.

        Your job is to ask only one open-ended follow-up question at a time, based solely on what the user just said in their journal entry or response. Your tone should be warm, curious, and non-judgmental — like a soft voice in the user's head helping them unpack what they're feeling and why.

        Every question should:

        *   Be deeply relevant to what the user just shared (no randomness or generic prompts)
        *   Encourage emotional honesty, self-discovery, or introspection
        *   Help the user explore how an experience made them feel, what it meant to them, or what they learned
        *   Avoid summarizing or responding — just ask a single, thoughtfully chosen question
        *   Reflect the idea that these entries might one day be read or listened to by their future self

        Examples of good follow-up angles include:

        *   "What part of that experience stuck with you the most?"
        *   "Why do you think that moment impacted you more than others?"
        *   "What do you wish you could say to yourself in that moment?"
        *   "If this happened again, how would you want to show up differently?"

        If the user seems to be reaching a natural conclusion in their entry, it's okay to gently signal the end with a wrap-up style question like:

        *   "Is there anything else you need to let out before we close this chapter?"
        *   "Would your future self understand how you felt today, or is there more to share?"

        Pick only the best possible question based on where they are in the conversation — as if you only had one chance to help them go a layer deeper.
        """ ]

        // Prepend the system prompt to the history messages
        let messages: [[String: String]] = [systemPrompt] + history.map { ["role": $0.role.rawValue, "content": $0.content] }

        // Construct the request body manually
        let requestBody: [String: Any] = [
            "model": "gpt-4", // Or use client.configuration.model if set?
            "messages": messages,
            "max_tokens": 60,
            "temperature": 0.75
        ]

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw GPTError.setupError("Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw GPTError.requestFailed(error) // Failed to encode body
        }

        // Perform the network request manually
        do {
            print("📡 Performing manual URLSession request...")
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GPTError.invalidResponse // Not an HTTP response
            }

            print("↔️ Received HTTP status code: \(httpResponse.statusCode)")

            // Check for non-200 status codes
            guard httpResponse.statusCode == 200 else {
                // Try to decode potential OpenAI error structure from data
                let errorDescription = String(data: data, encoding: .utf8) ?? "Unable to decode error data"
                print("❌ API Error Response Body: \(errorDescription)")
                throw GPTError.requestFailed(NSError(domain: "OpenAIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned status \(httpResponse.statusCode). \(errorDescription)"]))
            }

            // Decode the response using our flexible struct
            let decoder = JSONDecoder()
            let result = try decoder.decode(FlexibleChatCompletionResponse.self, from: data)
             print("✅ Successfully decoded response with flexible struct.")
             print("    System Fingerprint: \(result.system_fingerprint ?? "nil")") // Log decoded fingerprint

            guard let content = result.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty else {
                print("❌ Could not extract content from response.")
                throw GPTError.invalidResponse
            }
            print("💬 Extracted content: \(content)")
            return content

        } catch let error as DecodingError {
             print("💥 Decoding Error: \(error)")
             throw GPTError.requestFailed(error) // Propagate decoding error
        } catch {
            print("💥 Network or other error: \(error)")
            throw GPTError.requestFailed(error) // Propagate other errors
        }
    }
}
