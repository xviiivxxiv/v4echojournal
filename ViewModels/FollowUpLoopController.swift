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
    private let journalStorage: JournalStorage

    private var initialEntry: JournalEntryCD?
    private var currentFollowUp: FollowUpCD?
    private var chatHistory: [ChatMessage] = []
    private var cancellables = Set<AnyCancellable>()
    private var fileNameBase: String = ""
    private var requestTimestamps: [Date] = []
    private let latencyThreshold: TimeInterval = 4.0 // Seconds
    private let latencyWindowSize = 3 // Check average over last 3 requests
    private var keywordsHaveBeenProcessed = false // New flag
    private var feelingsHaveBeenProcessed = false // New flag
    private var summaryHasBeenProcessed = false // New flag for summary

    // Define the emotion categories and emotions
    private let emotionCategories: [String: [String]] = [
        "Great": ["Ecstatic", "Joyful", "Elated", "Blissful", "Euphoric", "Exuberant", "Radiant", "Triumphant", "Inspired", "Grateful", "Blessed", "Loved", "Proud", "Hopeful", "Optimistic"],
        "Good": ["Happy", "Excited", "Pleased", "Content", "Satisfied", "Cheerful", "Upbeat", "Confident", "Enthusiastic", "Amused", "Calm", "Relaxed", "Peaceful", "Secure", "Motivated"],
        "Fine": ["Okay", "Neutral", "Indifferent", "Pensive", "Reflective", "Thoughtful", "Curious", "Contemplative", "Ambivalent", "Reserved", "Unsure", "Uncertain", "Meh"],
        "Bad": ["Sad", "Annoyed", "Irritated", "Frustrated", "Worried", "Anxious", "Nervous", "Disappointed", "Stressed", "Tired", "Fatigued", "Bored", "Lonely", "Guilty", "Regretful", "Confused", "Overwhelmed", "Vulnerable"],
        "Terrible": ["Angry", "Furious", "Depressed", "Miserable", "Despairing", "Hopeless", "Terrified", "Scared", "Panicked", "Grief-stricken", "Betrayed", "Resentful", "Ashamed", "Humiliated", "Powerless", "Exhausted"]
    ]

    init(
        context: NSManagedObjectContext,
        gptService: GPTService = GPTService.shared,
        transcriptionService: TranscriptionServiceProtocol,
        audioRecorder: AudioRecordingService = AudioRecorder.shared,
        networkMonitor: NetworkMonitor = NetworkMonitor.shared,
        journalStorage: JournalStorage = CoreDataStorage()
    ) {
        self.managedObjectContext = context
        self.gptService = gptService
        self.transcriptionService = transcriptionService
        self.audioRecorder = audioRecorder
        self.networkMonitor = networkMonitor
        self.journalStorage = journalStorage

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
                    Task { await self.processFullConversation() }
                    return
                }

                let newFollowUp = FollowUpCD(context: managedObjectContext)
                newFollowUp.id = UUID()
                newFollowUp.question = question
                newFollowUp.createdAt = Date()
                newFollowUp.journalEntry = entry

                try managedObjectContext.save()

                // Save AI message to ConversationMessage
                do {
                    try journalStorage.saveMessage(
                        for: entry,
                        text: question,
                        sender: "ai",
                        timestamp: newFollowUp.createdAt ?? Date()
                    )
                    print("💾 AI message saved to ConversationMessage")
                } catch {
                    print("❌ Error saving AI message to ConversationMessage: \(error.localizedDescription)")
                    // Decide if this error should halt the process or just be logged
                }

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

            // Save User message to ConversationMessage
            if let entry = initialEntry {
                do {
                    try journalStorage.saveMessage(
                        for: entry,
                        text: text,
                        sender: "user",
                        timestamp: followUp.answeredAt ?? Date()
                    )
                    print("💾 User message saved to ConversationMessage")
                } catch {
                    print("❌ Error saving user message to ConversationMessage: \(error.localizedDescription)")
                    // Decide if this error should halt the process or just be logged
                }
            } else {
                print("❌ Cannot save user message: initialEntry is nil.")
            }

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

    // Method to get sorted messages from the JournalEntryCD
    private func getSortedMessages(for entry: JournalEntryCD) -> [ConversationMessage] {
        guard let messages = entry.messages as? NSOrderedSet else {
            return []
        }
        return (messages.array as? [ConversationMessage] ?? []).sorted {
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast)
        }
    }

    // Renamed and expanded method
    public func processFullConversation() async {
        guard let entry = initialEntry else { return }
        
        // Process keywords and headline first
        if !keywordsHaveBeenProcessed {
            print("▶️ Processing keywords and headline for entry: \(entry.id?.uuidString ?? "N/A")")
            let messages = getSortedMessages(for: entry)
            let fullConversationText = messages.compactMap { $0.text }.joined(separator: "\n\n")

            if !fullConversationText.isEmpty {
                do {
                    print("  Calling gptService.extractKeywords for full conversation...")
                    let extractedKeywords = try await gptService.extractKeywords(from: fullConversationText, count: 3)
                    var generatedHeadline: String? = nil

                    if !extractedKeywords.isEmpty {
                        print("  Keywords extracted from conversation: \(extractedKeywords.joined(separator: ", "))")
                        do {
                            print("    Calling gptService.generateHeadline...")
                            generatedHeadline = try await gptService.generateHeadline(fromKeywords: extractedKeywords)
                            print("    Headline generated: '\(generatedHeadline ?? "N/A")'")
                        } catch {
                            print("    ❌ Error generating headline: \(error.localizedDescription)")
                        }
                        try journalStorage.updateKeywordsAndHeadline(for: entry, keywords: extractedKeywords, headline: generatedHeadline)
                        print("  ✅ Keywords and headline updated in CoreData.")
                    } else {
                        print("  ℹ️ No keywords extracted. Headline generation skipped.")
                        try journalStorage.updateKeywordsAndHeadline(for: entry, keywords: [], headline: nil)
                    }
                    keywordsHaveBeenProcessed = true
                } catch {
                    print("❌ Error during keyword/headline processing: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ Full conversation text is empty. Skipping keyword/headline processing.")
                keywordsHaveBeenProcessed = true // Mark as processed to avoid re-trying
            }
        } else {
            print("ℹ️ Keywords and headline already processed for this entry.")
        }

        // Now process emotions
        if !feelingsHaveBeenProcessed {
            print("▶️ Processing emotions for entry: \(entry.id?.uuidString ?? "N/A")")
            let messages = getSortedMessages(for: entry) // Re-fetch or pass if already available
            let fullConversationText = messages.compactMap { $0.text }.joined(separator: "\n\n")

            if !fullConversationText.isEmpty {
                do {
                    print("  Calling gptService.assessEmotions for full conversation...")
                    let identifiedFeelings = try await gptService.assessEmotions(from: fullConversationText, emotionCategories: self.emotionCategories)
                    if !identifiedFeelings.isEmpty {
                        print("  Emotions identified: \(identifiedFeelings.map { "\($0.name) (\($0.category))" }.joined(separator: ", "))")
                        try journalStorage.saveIdentifiedFeelings(for: entry, feelings: identifiedFeelings)
                        print("  ✅ Identified feelings saved in CoreData.")
                    } else {
                        print("  ℹ️ No specific emotions identified from the conversation.")
                        // Optionally save an empty array to signify processing happened
                         try journalStorage.saveIdentifiedFeelings(for: entry, feelings: [])
                    }
                    feelingsHaveBeenProcessed = true
                } catch {
                    print("❌ Error during emotion assessment or saving: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ Full conversation text is empty. Skipping emotion assessment.")
                feelingsHaveBeenProcessed = true // Mark as processed
            }
        } else {
            print("ℹ️ Emotions already processed for this entry.")
        }

        // MARK: - AI Summary Processing
        if !summaryHasBeenProcessed {
            print("▶️ Processing AI Summary for entry: \(entry.id?.uuidString ?? "N/A")")
            // Re-fetch or ensure fullConversationText is available if not passed down/scoped
            let messages = getSortedMessages(for: entry)
            let fullConversationText = messages.compactMap { $0.text }.joined(separator: "\n\n")

            if !fullConversationText.isEmpty {
                do {
                    print("  Calling gptService.generateSummary for full conversation...")
                    let generatedSummary = try await gptService.generateSummary(for: fullConversationText)

                    if !generatedSummary.isEmpty {
                        entry.aiSummary = generatedSummary
                        try managedObjectContext.save() // Save context after updating the entry
                        print("  ✅ AI Summary generated and saved to CoreData: \(generatedSummary.prefix(100))..." )
                    } else {
                        print("  ℹ️ GPTService returned an empty summary. Nothing to save.")
                    }
                    summaryHasBeenProcessed = true
                } catch {
                    print("❌ Error during AI Summary generation or saving: \(error.localizedDescription)")
                    // Do not set summaryHasBeenProcessed = true, to allow potential retry
                }
            } else {
                print("⚠️ Full conversation text is empty. Skipping AI Summary generation.")
                summaryHasBeenProcessed = true // Mark as processed to avoid re-trying for an empty conversation
            }
        } else {
            print("ℹ️ AI Summary already processed for this entry.")
        }
    }

    // Call this when the user explicitly ends the conversation or navigates away
    public func userDidEndConversation() {
        print("▶️ FollowUpLoopController: userDidEndConversation called.")
        // Potentially cancel ongoing tasks, like audio recording or a pending GPT call if any
        // For now, just ensure the state reflects finished and attempt keyword processing.
        if currentState != .finished {
            currentState = .finished // Or a specific state like .userEnded
            // If audioRecorder has a cancel, call it: audioRecorder.cancelRecording()
        }
        Task {
            await self.processFullConversation()
        }
    }
}
 