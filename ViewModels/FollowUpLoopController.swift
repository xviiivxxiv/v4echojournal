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

    private let managedObjectContext: NSManagedObjectContext
    private let gptService: GPTService
    private let transcriptionService: TranscriptionServiceProtocol
    private let audioRecorder: AudioRecordingService
    private let networkMonitor: NetworkMonitor

    private var initialEntry: JournalEntryCD?
    private var currentFollowUp: FollowUpCD?
    private var chatHistory: [ChatMessage] = []
    private var cancellables = Set<AnyCancellable>()

    init(
        context: NSManagedObjectContext,
        gptService: GPTService = GPTService.shared,
        transcriptionService: TranscriptionServiceProtocol = WhisperTranscriptionService(),
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

        audioRecorder.isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
    }

    func startLoop(for entry: JournalEntryCD) {
        print("🏁 [Controller] startLoop called for entry ID: \(entry.objectID)")
        guard networkMonitor.isConnected else {
            print("❌ [Controller] startLoop aborted: No network connection.")
            handleError("Cannot start follow-up loop offline.")
            return
        }
        print("➡️ [Controller] startLoop: Network connected. Setting initial entry.")
        initialEntry = entry
        print("➡️ [Controller] startLoop: Building initial chat history...")
        chatHistory = buildInitialChatHistory(from: entry)
        print("➡️ [Controller] startLoop: Setting state to thinking.")
        currentState = .thinking
        print("➡️ [Controller] startLoop: Calling generateNextFollowUp...")
        generateNextFollowUp()
        print("🏁 [Controller] startLoop finished.")
    }

    func startRecording() {
        guard case .listening = currentState else { return }
        Task {
            do {
                let fileURL: URL = try await audioRecorder.startRecording()
                print("🎙️ Recording started at path: \(fileURL.path)")
                // You can store `fileURL` somewhere if needed later for playback/upload
            } catch {
                handleError("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }

    func stopRecordingAndProcess() {
        guard case .listening = currentState, audioRecorder.isRecording.value else { return }
        Task {
            do {
                let fileURL: URL = try await audioRecorder.stopRecording()
                print("🛑 Recording stopped at path: \(fileURL.path)")
                currentState = .processingAnswer
                await processRecordedAnswer(audioURL: fileURL)
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
        print("➡️ [Controller] Entered generateNextFollowUp")
        guard let entry = initialEntry else {
            handleError("Initial entry missing."); return
        }
        guard networkMonitor.isConnected else {
            handleError("Cannot generate follow-up offline."); return
        }

        print("ℹ️ [Controller] Setting state to thinking.")
        currentState = .thinking
        showMicButton = false

        Task {
            print("🚀 [Controller] Starting Task in generateNextFollowUp")
            do {
                print("💬 [Controller] Current chat history count: \(chatHistory.count)")
                print("⏳ [Controller] About to call self.gptService.generateFollowUp")

                let question = try await self.gptService.generateFollowUp(history: chatHistory)

                print("✅ [Controller] gptService.generateFollowUp returned successfully.")

                if isStopPhrase(question) {
                    print("🏁 [Controller] GPT indicated end of conversation.")
                    currentState = .finished
                    return
                }

                print("💾 [Controller] Saving new follow-up question...")
                let newFollowUp = FollowUpCD(context: managedObjectContext)
                newFollowUp.id = UUID()
                newFollowUp.question = question
                newFollowUp.createdAt = Date()
                newFollowUp.journalEntry = entry

                try managedObjectContext.save()
                self.currentFollowUp = newFollowUp
                self.currentQuestion = question
                self.chatHistory.append(ChatMessage(role: .assistant, content: question))
                 print("✅ [Controller] Follow-up saved. Setting state to showingQuestion.")
                self.currentState = .showingQuestion

            } catch let gptError as GPTError {
                 print("💥 [Controller] Caught GPTError: \(gptError)")
                 handleError("Failed to generate follow-up: \(gptError.localizedDescription)")
            } catch {
                print("💥 [Controller] Caught non-GPTError: \(error) | Localized: \(error.localizedDescription)")
                handleError("Failed to generate follow-up: \(error.localizedDescription)")
            }
             print("🏁 [Controller] Exiting Task in generateNextFollowUp")
        }
         print("🏁 [Controller] Exiting generateNextFollowUp function body")
    }

    private func processRecordedAnswer(audioURL: URL) async {
        guard let followUp = currentFollowUp else {
            handleError("No follow-up context.")
            return
        }

        do {
            let audioData = try Data(contentsOf: audioURL)
            let text = try await transcriptionService.transcribeAudio(data: audioData)
            followUp.answer = text
            followUp.setValue(Date(), forKey: "answeredAt")
            try managedObjectContext.save()

            chatHistory.append(ChatMessage(role: .user, content: text))
            generateNextFollowUp()
        } catch {
            handleError("Transcription failed: \(error.localizedDescription)")
        }
    }

    private func buildInitialChatHistory(from entry: JournalEntryCD) -> [ChatMessage] {
        guard let text = entry.entryText else { return [] }
        return [ChatMessage(role: .user, content: text)]
    }

    private func isStopPhrase(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("anything else") || lower.contains("wrap up") || lower.contains("done reflecting")
    }

    private func handleError(_ message: String) {
        print("\u{1F4A5} Error: \(message)")
        if !isFinishedOrError {
            currentState = .error(message)
        }
    }

    private var isFinishedOrError: Bool {
        if case .finished = currentState { return true }
        if case .error = currentState { return true }
        return false
    }
}
