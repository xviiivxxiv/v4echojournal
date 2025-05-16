import Foundation

// Define Transcription Modes
public enum TranscriptionMode {
    case conversation // Short chunks, low latency expected
    case ramble       // Potentially long, single file
}

// MARK: - Protocol
// Make protocol public if needed by consumers outside the module
public protocol TranscriptionServiceProtocol {
    func transcribe(data: Data, mode: TranscriptionMode) async throws -> String
}

// MARK: - Custom Error Enum
// Make error public if needed by consumers outside the module
public enum TranscriptionError: Error, LocalizedError {
    case apiKeyMissing
    case networkError(Error)
    case invalidResponse
    case decodingError
    case apiError(statusCode: Int, details: String)

    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Missing OpenAI API Key. Please check configuration."
        case .networkError(let underlyingError):
            return "Network error during transcription: \(underlyingError.localizedDescription)"
        case .invalidResponse:
            return "Invalid response received from server (not HTTP)."
        case .decodingError:
            return "Failed to parse transcription JSON response."
        case .apiError(let statusCode, let details):
            return "API returned status code \(statusCode). Details: \(details)"
        }
    }
}

// MARK: - WhisperTranscriptionService (Reverted Name)
// Make class public
public final class WhisperTranscriptionService: TranscriptionServiceProtocol {

    // Make shared instance public
    public static let shared = WhisperTranscriptionService()

    private let apiEndpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    // Add a dedicated URLSession with a longer timeout for ramble mode
    private let rambleSession: URLSession
    // Add a dedicated URLSession with a shorter timeout for conversation mode
    private let conversationSession: URLSession

    // Private init for singleton
    private init() {
        // Configure ramble session (long timeout)
        let rambleConfig = URLSessionConfiguration.default
        rambleConfig.timeoutIntervalForRequest = 120 // 120 seconds for potentially long rambles
        self.rambleSession = URLSession(configuration: rambleConfig)
        
        // Configure conversation session (short timeout)
        let conversationConfig = URLSessionConfiguration.default
        conversationConfig.timeoutIntervalForRequest = 30 // 30 seconds for shorter conversation chunks
        self.conversationSession = URLSession(configuration: conversationConfig)
    }

    // MARK: - API Key Retrieval (Using Info.plist)
    // This can remain private as it's an internal detail
    private func getTranscriptionAPIKey() -> String? {
        print("▶️ TranscriptionService: getTranscriptionAPIKey() called.")
        let correctKeyName = "OpenAI_API_Key" // Corrected Case
        
        // --- Optional: Enhanced Debug Logging (can be removed later) ---
         if let infoDict = Bundle.main.infoDictionary {
            if let rawValue = infoDict[correctKeyName] {
                print("  TranscriptionService: Raw value for \(correctKeyName): \(rawValue) (Type: \(type(of: rawValue)))")
            } else {
                print("  TranscriptionService: Key '\(correctKeyName)' NOT FOUND in infoDictionary.")
            }
        } else {
            print("  TranscriptionService: Could not load infoDictionary from Bundle.main")
        }
        // --- End Enhanced Debug Logging ---

        // Use the correct key name variable
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: correctKeyName) as? String else {
            print("❌ TranscriptionService: Failed to get API key '\(correctKeyName)' from Info.plist")
                return nil
            }
        
        // Basic validation (keep this)
        if apiKey.starts(with: "sk-") && apiKey.count > 50 {
            print("✅ TranscriptionService: Found valid API Key from Info.plist")
            return apiKey
        } else {
            print("⚠️ TranscriptionService: API Key from Info.plist appears invalid (format/length)")
            return nil
        }
    }

    // MARK: - Transcribe Audio
    // Make the protocol method public
    public func transcribe(data: Data, mode: TranscriptionMode) async throws -> String {
        print("🎤 transcribe(mode: \(mode)): Function Entered.") // Log mode

        // Network Check
        guard await NetworkMonitor.shared.isConnected else {
            print("❌ Network Offline - Transcription skipped.")
            // Use the custom error enum
            throw TranscriptionError.networkError(NSError(domain: "NetworkMonitor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network Offline. Please connect to Wi-Fi or cellular."]))
        }

        print("🎤 transcribe(mode: \(mode)): Network check passed.")

        // --- API Key Check ---
        guard let apiKey = getTranscriptionAPIKey() else {
            print("❌ transcribe(mode: \(mode)): Missing or Invalid API Key from Info.plist - Transcription skipped.")
            throw TranscriptionError.apiKeyMissing
        }
         print("  transcribe(mode: \(mode)): Using API Key for request.")
        let tokenPrefix = apiKey.prefix(10)
        let tokenSuffix = apiKey.suffix(4)
        print("🎤 WhisperTranscriptionService: Using key starting with \(tokenPrefix)...\(tokenSuffix)")
        // --- End API Key Check ---

        var request = URLRequest(url: self.apiEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Multipart boundary
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // 📎 Model field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("whisper-1\r\n")

        // 📎 Audio file field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(data)
        body.append("\r\n")

        // 📎 End
        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        print("🔍 Request Headers: \(request.allHTTPHeaderFields ?? [:])")

        // MARK: - Response Handling (Using Decodable)
        struct WhisperResponse: Decodable {
            let text: String
        }

        // --- Select URLSession based on mode --- 
        let sessionToUse: URLSession
        switch mode {
        case .conversation:
            print("  Using conversationSession (30s timeout)")
            sessionToUse = self.conversationSession
        case .ramble:
            print("  Using rambleSession (120s timeout)")
            sessionToUse = self.rambleSession
        }
        // --- End Session Selection ---

        do {
             // Use the selected urlSession instance
            let (responseData, response) = try await sessionToUse.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP Response received.")
                throw TranscriptionError.invalidResponse
            }

            print("  transcribe(mode: \(mode)): Received HTTP status code: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorString = String(data: responseData, encoding: .utf8) ?? "Unknown API error"
                print("❌ transcribe(mode: \(mode)): Whisper API Error (\(httpResponse.statusCode)): \(errorString)")
                throw TranscriptionError.apiError(statusCode: httpResponse.statusCode, details: errorString)
            }

            do {
                let decodedResponse = try JSONDecoder().decode(WhisperResponse.self, from: responseData)
                print("✅ transcribe(mode: \(mode)): Transcription successful.")
                return decodedResponse.text
            } catch {
                 print("❌ transcribe(mode: \(mode)): Decoding Error: \(error)")
                 throw TranscriptionError.decodingError
            }
        } catch let error as TranscriptionError {
             print("❌ Transcription failed with known error: \(error.localizedDescription)")
            throw error // Re-throw known TranscriptionError
        } catch let error as URLError {
             print("❌ Network error during transcription: \(error.localizedDescription)")
             throw TranscriptionError.networkError(error)
        } catch {
             print("❌ Unexpected error during transcription: \(error.localizedDescription)")
             // Wrap unexpected errors as well
             throw TranscriptionError.networkError(error)
        }
    } // End of transcribe(mode:)

} // End of TranscriptionService class (formerly WhisperTranscriptionService)

// MARK: - Data Appending Extension
// Keep this private extension for convenience
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
 