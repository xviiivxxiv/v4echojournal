import SwiftUI
import AVFoundation

class TranscriptionViewModel: ObservableObject {
    @Published var transcriptionText: String = ""
    @Published var isTranscribing: Bool = false
    @Published var error: Error?
    
    private let transcriptionService: TranscriptionServiceProtocol
    
    init(transcriptionService: TranscriptionServiceProtocol) {
        self.transcriptionService = transcriptionService
    }
    
    func transcribe(fileURL: URL, mode: TranscriptionMode) async throws -> String {
        isTranscribing = true
        defer { isTranscribing = false }
        
        do {
            let audioData = try Data(contentsOf: fileURL)
            // Call the correct method on the injected service
            let transcription = try await transcriptionService.transcribe(data: audioData, mode: mode)
            
            await MainActor.run {
                // Only update text if it's relevant (maybe add mode check?)
                self.transcriptionText = transcription 
            }
            
            return transcription
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func reset() {
        transcriptionText = ""
        error = nil
    }
} 
 