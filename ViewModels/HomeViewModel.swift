import Foundation
import Combine
import SwiftUI
import CoreData

@MainActor
class HomeViewModel: ObservableObject {

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
        transcriptionService: TranscriptionServiceProtocol = WhisperTranscriptionService(),
        localAudioStorage: AudioStorageService = LocalAudioStorage(),
        coreDataStorage: JournalStorage = CoreDataStorage()
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionService = transcriptionService
        self.localAudioStorage = localAudioStorage
        self.coreDataStorage = coreDataStorage

        audioRecorder.isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recording in
                self?.isRecording = recording
            }
            .store(in: &cancellables)

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
        _ = try await AudioRecorder.shared.startRecording() // updated return value is file URL
    }

    private func stopRecordingAndTranscribe() async {
        do {
            let fileURL = try await AudioRecorder.shared.stopRecording()
            statusMessage = "Processing audio..."
            isLoading = true

            let data = try Data(contentsOf: fileURL)
            self.recordingData = data

            let transcription = try await transcriptionService.transcribeAudio(data: data)
            transcribedText = transcription
            statusMessage = "Transcription complete. Ready to save."
            isLoading = false

            await saveJournalEntry()

        } catch {
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

            statusMessage = "Journal entry saved! Generating follow-up..."
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
