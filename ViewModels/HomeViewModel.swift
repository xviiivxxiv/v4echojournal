import Foundation
import Combine
import SwiftUI
import CoreData
import OSLog

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

    // MARK: - Services
    private let audioRecorder: AudioRecordingService
    private let transcriptionService: TranscriptionServiceProtocol
    private let localAudioStorage: AudioStorageService
    private let coreDataStorage: JournalStorage

    private var recordingData: Data? = nil
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(
        audioRecorder: AudioRecordingService = AudioRecorder.shared,
        transcriptionService: TranscriptionServiceProtocol,
        localAudioStorage: AudioStorageService = LocalAudioStorage(),
        coreDataStorage: JournalStorage = CoreDataStorage()
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionService = transcriptionService
        self.localAudioStorage = localAudioStorage
        self.coreDataStorage = coreDataStorage

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
                statusMessage = "Transcription complete. Ready to save."
                isLoading = false

                await saveJournalEntry()

            } catch {
            logger.error("Error caught in stopRecordingAndTranscribe: Error Type: \(String(describing: type(of: error))), Description: \(error.localizedDescription, privacy: .public)") 
            errorMessage = "Failed to stop or transcribe: \(error.localizedDescription)"
            statusMessage = "Error processing audio."
                isLoading = false
        }
    }

    private func saveJournalEntry() async {
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
                createdAt: Date()
            )

            statusMessage = "Entry saved!"
            isLoading = false
            recordingData = nil
            transcribedText = ""

            if let savedEntry = coreDataStorage.fetchEntry(byId: entryId) {
                self.newlySavedEntry = savedEntry
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
}
