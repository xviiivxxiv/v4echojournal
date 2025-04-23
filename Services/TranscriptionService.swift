import Foundation

// MARK: - Protocol
protocol TranscriptionServiceProtocol {
    func transcribeAudio(data: Data) async throws -> String
}

// MARK: - WhisperTranscriptionService
class WhisperTranscriptionService: TranscriptionServiceProtocol {

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
        guard await NetworkMonitor.shared.isConnected else {
            print("❌ Network Offline - Transcription skipped.")
            throw TranscriptionError.apiError("You appear to be offline. Please connect to Wi-Fi or cellular.")
        }
        
        // ✅ Read API key securely from Info.plist
        guard let apiKey = Bundle.main.infoDictionary?["OpenAI_API_Key"] as? String,
              !apiKey.contains("YOUR_") else {
            throw TranscriptionError.missingAPIKey
        }

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
}

// MARK: - Data Appending Extension
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
