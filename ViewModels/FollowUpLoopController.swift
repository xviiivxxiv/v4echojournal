import Foundation
import CoreData
import AVFoundation
import Combine

@MainActor
class FollowUpLoopController: ObservableObject {

    enum LoopState: Equatable {
        case idle, thinking, showingQuestion, listening, processingAnswer, finished
        case error(String)

        static func ==(lhs: LoopState, rhs: LoopState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.thinking, .thinking), (.showingQuestion, .showingQuestion),
                 (.listening, .listening), (.processingAnswer, .processingAnswer), (.finished, .finished):
                return true
            case (.error, .error): return true
            default: return false
            }
        }
    }

    @Published var currentState: LoopState = .idle
    @Published var currentQuestion: String = ""
    @Published var isRecording: Bool = false
    @Published var showMicButton: Bool = false
    @Published var lastUserAnswer: String = ""
    @Published var isExperiencingHighLatency: Bool = false

    private let managedObjectContext: NSManagedObjectContext
    private let gptService: GPTService
    private let transcriptionService: TranscriptionServiceProtocol
    private let audioRecorder: AudioRecordingService
    private let networkMonitor: NetworkMonitor

    private var initialEntry: JournalEntryCD?
    private var currentFollowUp: FollowUpCD?
    private var chatHistory: [ChatMessage] = []
    private var cancellables = Set<AnyCancellable>()
    private var fileNameBase: String = ""
    private var requestTimestamps: [Date] = []
    private let latencyThreshold: TimeInterval = 4.0 // Seconds
    private let latencyWindowSize = 3 // Check average over last 3 requests

    init(
        context: NSManagedObjectContext,
        gptService: GPTService = GPTService.shared,
        transcriptionService: TranscriptionServiceProtocol,
        audioRecorder: AudioRecordingService = AudioRecorder.shared,
        networkMonitor: NetworkMonitor = NetworkMonitor.shared
    ) {
        self.managedObjectContext = context
        self.gptService = gptService
        self.transcriptionService = transcriptionService
        self.audioRecorder = audioRecorder
        self.networkMonitor = networkMonitor

        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                if !isConnected {
                    self?.handleError("No internet connection.")
                }
            }
            .store(in: &cancellables)

        audioRecorder.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
    }

    func startLoop(for entry: JournalEntryCD) {
        guard networkMonitor.isConnected else {
            handleError("Cannot start follow-up loop offline.")
            return
        }
        
        initialEntry = entry
        chatHistory = buildInitialChatHistory(from: entry)
        currentState = .thinking
        generateNextFollowUp()
    }

    func startRecording() {
        guard case .listening = currentState else { return }
        fileNameBase = UUID().uuidString
        
        Task {
            do {
                let success = try await audioRecorder.startRecording(fileNameBase: fileNameBase)
                if !success {
                    handleError("Failed to start recording")
                }
            } catch {
                handleError("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }

    func stopRecordingAndProcess() {
        guard case .listening = currentState else { return }
        
        Task {
            do {
                guard let audioURL = await audioRecorder.stopRecording() else {
                    handleError("Failed to get audio URL after recording")
                    return
                }
                currentState = .processingAnswer
                await processRecordedAnswer(audioURL: audioURL)
            } catch {
                handleError("Failed to stop recording: \(error.localizedDescription)")
            }
        }
    }

    func userReadyToAnswer() {
        guard case .showingQuestion = currentState else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.currentState = .listening
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.showMicButton = true
            }
        }
    }

    private func generateNextFollowUp() {
        guard let entry = initialEntry else {
            handleError("Initial entry missing.")
            return
        }

        currentState = .thinking
        showMicButton = false

        Task {
            do {
                let question = try await gptService.generateFollowUp(history: chatHistory)

                if isStopPhrase(question) {
                    currentState = .finished
                    return
                }

                let newFollowUp = FollowUpCD(context: managedObjectContext)
                newFollowUp.id = UUID()
                newFollowUp.question = question
                newFollowUp.createdAt = Date()
                newFollowUp.journalEntry = entry

                try managedObjectContext.save()
                currentFollowUp = newFollowUp
                currentQuestion = question
                chatHistory.append(ChatMessage(role: .assistant, content: question))
                currentState = .showingQuestion

            } catch {
                handleError("Failed to generate follow-up: \(error.localizedDescription)")
            }
        }
    }

    private func processRecordedAnswer(audioURL: URL) async {
        guard let followUp = currentFollowUp else {
            handleError("No follow-up context.")
            return
        }

        do {
            let audioData = try Data(contentsOf: audioURL)
            
            let startTime = Date()
            
            let text = try await transcriptionService.transcribe(data: audioData, mode: .conversation)
            
            let endTime = Date()
            checkLatency(start: startTime, end: endTime)

            lastUserAnswer = text
            followUp.answer = text
            followUp.answeredAt = Date()
            try managedObjectContext.save()

            chatHistory.append(ChatMessage(role: .user, content: text))
            generateNextFollowUp()
        } catch {
            handleError("Transcription failed: \(error.localizedDescription)")
        }
    }
    
    private func handleError(_ message: String) {
        print("❌ [Controller] Error: \(message)")
        currentState = .error(message)
    }

    private func buildInitialChatHistory(from entry: JournalEntryCD) -> [ChatMessage] {
        var history: [ChatMessage] = []
        if let entryText = entry.entryText {
            history.append(ChatMessage(role: .user, content: entryText))
        }
        return history
    }

    private func isStopPhrase(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("thank you for sharing") || 
               lowercased.contains("that's all for now") ||
               lowercased.contains("we've covered everything")
    }

    private func checkLatency(start: Date, end: Date) {
        let duration = end.timeIntervalSince(start)
        print("⏱️ Transcription Request Duration: \(String(format: "%.2f", duration))s")
        
        requestTimestamps.append(end)
        if requestTimestamps.count > latencyWindowSize {
            requestTimestamps.removeFirst(requestTimestamps.count - latencyWindowSize)
        }
        
        if requestTimestamps.count == latencyWindowSize {
            var totalDuration: TimeInterval = 0
            if let firstTimestamp = requestTimestamps.first {
                 totalDuration = end.timeIntervalSince(firstTimestamp)
                 let averageDuration = totalDuration / Double(latencyWindowSize - 1)
                 print("⏱️ Average Transcription Duration (last \(latencyWindowSize)): \(String(format: "%.2f", averageDuration))s")
                isExperiencingHighLatency = averageDuration > latencyThreshold
            } else {
                isExperiencingHighLatency = duration > latencyThreshold
            }

        } else {
            isExperiencingHighLatency = duration > latencyThreshold
        }
        
        if isExperiencingHighLatency {
            print("⚠️ High latency detected.")
        } else {
             print("✅ Latency within threshold.")
        }
    }
}
 