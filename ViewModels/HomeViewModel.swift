import Foundation
import Combine
import SwiftUI
import CoreData
import OSLog

// ADDED: Define the different modes for the journaling entry screen
enum JournalEntryMode: Hashable {
    case standard
    case challenge(attempt: ChallengeAttempt, dayIndex: Int)

    // Helper to get the associated Challenge object
    var challenge: Challenge? {
        guard case .challenge(let attempt, _) = self,
              let challengeID = attempt.challengeID,
              let challenge = ChallengeData.samples.first(where: { $0.id.uuidString == challengeID }) else {
            return nil
        }
        return challenge
    }
    
    // ADDED: Centralized theme color for each mode
    var themeColor: Color {
        switch self {
        case .standard:
            return Color.buttonBrown // Default brown for standard journal
        case .challenge:
            return challenge?.themeColor ?? .gray // Challenge's theme color, or gray as a fallback
        }
    }
}

@MainActor
class HomeViewModel: ObservableObject {

    // Create a logger instance
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.yourapp.v4EchoJournal", category: "HomeViewModel")

    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var transcribedText: String = ""
    @Published var statusMessage: String = "Tap the mic to start recording."
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var newlySavedEntry: JournalEntryCD? = nil
    @Published var showOfflineAlert: Bool = false

    // Modal Presentation State (NEW)
    @Published var showDateInteractionModal: Bool = false
    @Published var tappedDateForModal: Date? = nil
    @Published var entryForTappedDate: JournalEntryCD? = nil

    // NEW: Flag to indicate when the view model is ready to be displayed
    @Published var isReady = false

    // ADDED: Properties for Challenge Mode
    @Published var activeChallenges: [ChallengeAttempt] = []
    @Published var availableModes: [JournalEntryMode] = [.standard]
    @Published var selectedMode: JournalEntryMode = .standard
    @Published var requestedMode: JournalEntryMode? = nil

    // MARK: - Services
    private let audioRecorder: AudioRecordingService
    private let transcriptionService: TranscriptionServiceProtocol
    private let localAudioStorage: AudioStorageService
    private let coreDataStorage: JournalStorage
    private let gptService: GPTService

    private var recordingData: Data? = nil
    private var cancellables = Set<AnyCancellable>()
    private let viewContext = PersistenceController.shared.container.viewContext

    // MARK: - Initialization
    init(
        audioRecorder: AudioRecordingService = AudioRecorder.shared,
        transcriptionService: TranscriptionServiceProtocol,
        localAudioStorage: AudioStorageService = LocalAudioStorage(),
        coreDataStorage: JournalStorage = CoreDataStorage(),
        gptService: GPTService = GPTService.shared
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionService = transcriptionService
        self.localAudioStorage = localAudioStorage
        self.coreDataStorage = coreDataStorage
        self.gptService = gptService

        audioRecorder.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)

        audioRecorder.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                 self?.errorMessage = "Audio Recording Error: \(error.localizedDescription)"
                 self?.isLoading = false
                 self?.statusMessage = "Error during recording."
             }
             .store(in: &cancellables)

        // ADDED: Fetch challenges on init
        fetchActiveChallenges()
    }

    // MARK: - Challenge Logic (Moved from ChallengesViewModel)

    func startChallenge(challenge: Challenge) {
        // Prevent starting a challenge that's already active
        guard !activeChallenges.contains(where: { $0.challengeID == challenge.id.uuidString }) else {
            print("Challenge already started.")
            return
        }

        let newAttempt = ChallengeAttempt(context: viewContext)
        newAttempt.id = UUID()
        newAttempt.challengeID = challenge.id.uuidString
        newAttempt.startDate = Date()
        newAttempt.completedDays = ""

        do {
            try viewContext.save()
            print("✅ Challenge started successfully!")
            // Refresh the lists to update the UI
            fetchActiveChallenges()

            // After starting, set this as the requested mode for immediate navigation
            let dayIndex = 0 // Always start at day 0
            self.requestedMode = .challenge(attempt: newAttempt, dayIndex: dayIndex)

        } catch {
            print("❌ Error saving new challenge attempt: \(error.localizedDescription)")
            // Optionally, handle the error (e.g., show an alert to the user)
        }
    }

    // MARK: - Public Methods
    func toggleRecording() {
        errorMessage = nil
        Task {
        if isRecording {
                await stopRecordingAndTranscribe()
        } else {
                do {
                    try await startRecording()
                } catch {
                    errorMessage = "Failed to start recording: \(error.localizedDescription)"
                    statusMessage = "Error: Could not start recording."
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func startRecording() async throws {
        recordingData = nil
        transcribedText = ""
        statusMessage = "Recording... Tap again to stop."
        let fileNameBase = UUID().uuidString
        _ = try await audioRecorder.startRecording(fileNameBase: fileNameBase)
    }

    private func stopRecordingAndTranscribe() async {
        logger.debug("stopRecordingAndTranscribe called.")
        do {
            logger.debug("Attempting to stop recording...")
            guard let fileURL = try await audioRecorder.stopRecording() else {
                throw NSError(domain: "com.echojournal", code: -1, userInfo: [NSLocalizedDescriptionKey: "No audio file URL returned"])
            }
            
            logger.debug("Recording stopped. FileURL: \(fileURL.path, privacy: .public)")
            
            statusMessage = "Uploading audio..."
        isLoading = true

            logger.debug("Attempting to read data from URL...")
            let data = try Data(contentsOf: fileURL)
            self.recordingData = data
            logger.debug("Data read successfully (\(data.count) bytes). Attempting transcription...")

            statusMessage = "Transcribing audio..."

            // Use .ramble mode for potentially long initial recordings
            let transcription = try await transcriptionService.transcribe(data: data, mode: .ramble)
            logger.debug("Transcription service returned.")
            
            transcribedText = transcription
            statusMessage = "Transcription complete. Extracting keywords..."
            isLoading = false

            // Directly call saveJournalEntry without keywords. Keywords will be processed later.
            statusMessage = "Saving initial entry..."
            await saveJournalEntry(extractedKeywords: nil)

            } catch {
            logger.error("Error caught in stopRecordingAndTranscribe: Error Type: \(String(describing: type(of: error))), Description: \(error.localizedDescription, privacy: .public)") 
            errorMessage = "Failed to stop or transcribe: \(error.localizedDescription)"
            statusMessage = "Error processing audio."
                isLoading = false
        }
    }

    private func saveJournalEntry(extractedKeywords: String? = nil) async {
        guard let audioData = recordingData, !transcribedText.isEmpty else {
            errorMessage = "Error: Missing audio data or transcription text."
            statusMessage = "Cannot save. Missing data."
            isLoading = false
            return
        }

        statusMessage = "Saving entry..."
        isLoading = true
        errorMessage = nil
        let entryId = UUID()
        let filename = "\(entryId).m4a"

        do {
            let audioURL = try localAudioStorage.saveAudio(data: audioData, filename: filename)

            try coreDataStorage.saveEntry(
                id: entryId,
                entryText: transcribedText,
                audioURL: audioURL,
                createdAt: Date(),
                keywords: extractedKeywords
            )

            statusMessage = "Entry saved!"
            isLoading = false
            recordingData = nil
            transcribedText = ""

            if let savedEntry = coreDataStorage.fetchEntry(byId: entryId) {
                self.newlySavedEntry = savedEntry
                // Save the initial transcribed text as the first message
                do {
                    try coreDataStorage.saveMessage(
                        for: savedEntry, 
                        text: savedEntry.entryText ?? "", // Use the text from the saved entry
                        sender: "user", 
                        timestamp: savedEntry.createdAt ?? Date() // Use the entry's creation date
                    )
                    logger.debug("Initial user message saved for entry ID: \(entryId)")
                } catch {
                    logger.error("Failed to save initial user message for entry ID: \(entryId). Error: \(error.localizedDescription)")
                }
                
                // ADDED: Logic to handle saving a challenge entry
                switch selectedMode {
                case .standard:
                    // No extra logic needed for a standard entry
                    break
                case .challenge(let attempt, let dayIndex):
                    // Link the journal entry to the challenge attempt
                    savedEntry.challengeAttempt = attempt
                    
                    // Update the completed days on the attempt
                    let dayNumber = dayIndex + 1
                    var completed = attempt.completedDaysSet
                    completed.insert(dayNumber)
                    
                    // Convert back to a sorted string for consistent storage
                    attempt.completedDays = completed.sorted().map(String.init).joined(separator: ",")
                    
                    // Save the context again to persist the relationship and updated progress
                    do {
                        try viewContext.save()
                        logger.debug("✅ Successfully linked entry to challenge and updated progress.")
                        // Refresh the UI to show new progress
                        fetchActiveChallenges()
                    } catch {
                        logger.error("❌ Failed to save challenge progress: \(error.localizedDescription)")
                    }
                }
                
            } else {
                print("❌ Failed to fetch saved entry with ID: \(entryId)")
                errorMessage = "Failed to fetch saved entry after saving."
                statusMessage = "Error after saving."
            }

        } catch {
            errorMessage = "Failed to save journal entry: \(error.localizedDescription)"
            statusMessage = "Error saving entry."
            isLoading = false

             if let urlToDelete = localAudioStorage.getAudioURL(filename: filename) {
                 try? localAudioStorage.deleteAudio(at: urlToDelete)
                 print("Cleaned up audio file after Core Data save failure.")
             }
        }
    }

    // ADDED: Function to fetch active challenges and set up available modes
    func fetchActiveChallenges() {
        print("🎯 fetchActiveChallenges() called")
        isLoading = true
        let request: NSFetchRequest<ChallengeAttempt> = ChallengeAttempt.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChallengeAttempt.startDate, ascending: true)]
        
        do {
            print("🔍 Fetching challenge attempts from Core Data...")
            let attempts = try viewContext.fetch(request)
            print("✅ Fetched \(attempts.count) challenge attempts")
            self.activeChallenges = attempts
            
            // Rebuild the available modes list
            var modes: [JournalEntryMode] = [.standard]
            for attempt in attempts {
                // Ensure the challenge data for this attempt actually exists before creating a mode for it.
                // This prevents the "Could not load details" bug.
                if let challenge = getChallenge(from: attempt) {
                    let completedCount = attempt.completedDays?.split(separator: ",").count ?? 0
                    let dayIndex = min(completedCount, challenge.durationInDays - 1)
                    modes.append(.challenge(attempt: attempt, dayIndex: dayIndex))
                }
            }
            self.availableModes = modes

            // If the previously selected mode is no longer available, default to standard
            if !self.availableModes.contains(self.selectedMode) {
                self.selectedMode = .standard
            }
            isLoading = false
            print("✅ Setting isReady = true (success)")
            isReady = true // Mark as ready after the first successful fetch
        } catch {
            print("❌ Error fetching active challenges: \(error.localizedDescription)")
            isLoading = false
            print("✅ Setting isReady = true (failure)")
            isReady = true // Also mark as ready on failure to unblock the UI
        }
    }
    
    // ADDED: Helper to get Challenge data from an attempt
    func getChallenge(from attempt: ChallengeAttempt) -> Challenge? {
        guard let challengeID = attempt.challengeID else { return nil }
        return ChallengeData.samples.first { $0.id.uuidString == challengeID }
    }
}
