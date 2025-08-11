import Foundation
import Combine

@MainActor
class AhaOnboardingViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var transcribedText: String? = nil
    @Published var aiFollowUpQuestion: String? = nil
    @Published var statusMessage: String = "Loading..." // Default message
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    enum OnboardingState {
        case idle, recording, transcribing, thinking, showingAhaMoment
    }
    @Published var currentState: OnboardingState = .idle

    // MARK: - Services
    private let audioRecorder: AudioRecordingService
    private let transcriptionService: TranscriptionServiceProtocol
    private let gptService: GPTService
    private let persistenceManager: OnboardingPersistenceManager
    
    private var cancellables = Set<AnyCancellable>()

    init(
        audioRecorder: AudioRecordingService = AudioRecorder.shared,
        transcriptionService: TranscriptionServiceProtocol = WhisperTranscriptionService.shared,
        gptService: GPTService = GPTService.shared,
        persistenceManager: OnboardingPersistenceManager = OnboardingPersistenceManager()
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionService = transcriptionService
        self.gptService = gptService
        self.persistenceManager = persistenceManager

        // Subscribe to recorder state
        audioRecorder.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
            
        // Generate the dynamic prompt upon initialization
        generateDynamicPrompt()
    }

    func handleMicButtonTapped() {
        if isRecording {
            stopRecordingAndProcess()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        Task {
            do {
                currentState = .recording
                statusMessage = "Recording... Tap again to stop."
                try await audioRecorder.startRecording(fileNameBase: "onboarding_temp")
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
                currentState = .idle
            }
        }
    }
    
    private func stopRecordingAndProcess() {
        Task {
            do {
                guard let fileURL = try await audioRecorder.stopRecording() else {
                    throw NSError(domain: "com.yourapp.onboarding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio file not found."])
                }
                
                let data = try Data(contentsOf: fileURL)

                // Transcribe
                currentState = .transcribing
                statusMessage = "Transcribing your reflection..."
                isLoading = true
                let transcription = try await transcriptionService.transcribe(data: data, mode: .ramble)
                self.transcribedText = transcription
                
                // Save transcription to persistence
                var onboardingData = persistenceManager.getOnboardingData()
                onboardingData.reflectionTranscript = transcription
                persistenceManager.saveOnboardingData(onboardingData)
                
                // Get AI Follow-up
                currentState = .thinking
                statusMessage = "Thinking of the perfect question..."
                let history = [ChatMessage(role: .user, content: transcription)]
                let followUp = try await gptService.generateFollowUp(history: history)
                self.aiFollowUpQuestion = followUp
                
                // Save follow-up to persistence
                onboardingData.reflectionFollowUp = followUp
                persistenceManager.saveOnboardingData(onboardingData)
                
                // Move to final state
                isLoading = false
                currentState = .showingAhaMoment
                statusMessage = "Here's your first follow-up:"

            } catch {
                errorMessage = "There was an error processing your recording. Please try again."
                currentState = .idle
                isLoading = false
            }
        }
    }
    
    private func generateDynamicPrompt() {
        let onboardingData = persistenceManager.getOnboardingData()
        let goal = onboardingData.selectedGoal
        let tone = onboardingData.selectedTone
        
        print("🧠 Generating dynamic prompt with Goal: '\(goal ?? "N/A")', Tone: '\(tone ?? "N/A")'")
        
        // Default prompt as a fallback
        var prompt = "What's on your mind today?"
        
        switch (goal, tone) {
        // Personal Growth
        case (let g, _) where g?.contains("personal growth") == true:
            prompt = "What inspired you to start working on your personal growth?"
            
        // Reflect on day
        case (let g, let t) where g?.contains("reflect on my day") == true && t?.contains("Fun & curious") == true:
            prompt = "What’s one thing from today that stuck in your mind?"
        case (let g, _) where g?.contains("reflect on my day") == true:
            prompt = "What's one moment from today you'd like to remember?"
            
        // Processing thoughts & feelings
        case (let g, let t) where g?.contains("processing thoughts & feelings") == true && t?.contains("Deep & thoughtful") == true:
            prompt = "Are there any particular feelings that have been coming up lately?"
        case (let g, _) where g?.contains("processing thoughts & feelings") == true:
            prompt = "What's one thought or feeling that's been taking up space in your mind?"
            
        default:
            break // Use the default prompt
        }
        
        self.statusMessage = prompt
    }
} 