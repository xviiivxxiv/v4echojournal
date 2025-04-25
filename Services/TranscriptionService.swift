import Foundation

// MARK: - Protocol
protocol TranscriptionServiceProtocol {
    func transcribeAudio(data: Data) async throws -> String
}

// MARK: - WhisperTranscriptionService
final class WhisperTranscriptionService: TranscriptionServiceProtocol {

    static let shared = WhisperTranscriptionService()

    private let apiEndpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    // MARK: - Errors
    enum TranscriptionError: Error {
        case missingAPIKey
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case dataConversionError
    }

    // MARK: - Transcribe Audio
    func transcribeAudio(data: Data) async throws -> String {
        // Network Check
        // Add await because NetworkMonitor is @MainActor
        guard await NetworkMonitor.shared.isConnected else {
            print("❌ Network Offline - Transcription skipped.")
            throw TranscriptionError.apiError("You appear to be offline. Please connect to Wi-Fi or cellular.")
        }
        
        // ✅ Read API key securely (prioritizing Info.plist)
        guard let apiKey = getTranscriptionAPIKey(), !apiKey.isEmpty else {
            throw TranscriptionError.missingAPIKey
        }
        
        // Safely log the key being used for transcription
        let tokenPrefix = apiKey.prefix(10)
        let tokenSuffix = apiKey.suffix(4)
        print("🎤 TranscriptionService: Using key starting with \(tokenPrefix)...\(tokenSuffix)")

        var request = URLRequest(url: apiEndpoint)
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

        // Log headers just before sending
        print("🔍 Request Headers: \(request.allHTTPHeaderFields ?? [:])")

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorString = String(data: responseData, encoding: .utf8) ?? "Unknown API error"
                print("❌ Whisper API Error (\(httpResponse.statusCode)): \(errorString)")
                throw TranscriptionError.apiError("Status Code: \(httpResponse.statusCode) - \(errorString)")
            }

            // ✅ Extract text from response
            if let jsonResponse = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let transcribedText = jsonResponse["text"] as? String {
                return transcribedText
            } else {
                throw TranscriptionError.invalidResponse
            }

        } catch let error as TranscriptionError {
            print("❌ Transcription failed: \(error)")
            throw error
        } catch {
            print("❌ Network error during transcription: \(error.localizedDescription)")
            throw TranscriptionError.networkError(error)
        }
    }

    // Helper function to encapsulate API key loading for Transcription
    private func getTranscriptionAPIKey() -> String? {
        var apiKey: String? = nil
        var keySource: String = "Unknown"

        // 1. Try loading from Environment Variable
        if let keyFromEnv = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !keyFromEnv.isEmpty,
           !keyFromEnv.starts(with: "YOUR_") {
            // Trim whitespace just in case
            apiKey = keyFromEnv.trimmingCharacters(in: .whitespacesAndNewlines)
            keySource = "Environment Variable"
        } 
        
        // 2. Try loading from Info.plist (Fallback 1)
        if apiKey == nil {
            if let infoDict = Bundle.main.infoDictionary,
               let keyFromInfoPlist = infoDict["OpenAI_API_Key"] as? String,
               !keyFromInfoPlist.isEmpty,
               !keyFromInfoPlist.starts(with: "YOUR_") {
                apiKey = keyFromInfoPlist
                keySource = "Info.plist"
            } else {
                 keySource = "Info.plist (Not Found/Invalid)"
            }
        }

        // 3. Fallback ONLY in DEBUG
        #if DEBUG
        if apiKey == nil {
            print("⚠️ TranscriptionService DEBUG: No fallback key provided. Ensure Env Var or Info.plist is set.")
            // apiKey = "YOUR_TRANSCRIPTION_DEBUG_FALLBACK_KEY_HERE" // REMOVED HARDCODED KEY
            // keySource = "Hardcoded (DEBUG)"
        }
        #endif
        
        print("🎤 TranscriptionService: Key loaded from [\(keySource)]")
        return apiKey
    }
}

// MARK: - Data Appending Extension
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
