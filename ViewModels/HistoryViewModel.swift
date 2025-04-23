import Foundation
import Combine
import SwiftUI // For @MainActor
import AVFoundation // For audio playback
import CoreData // Import CoreData

@MainActor // Ensure UI updates are on the main thread
// Inherit from NSObject to conform to NSObjectProtocol required by AVAudioPlayerDelegate
class HistoryViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // MARK: - Published Properties (State)
    // Use JournalEntryCD from Core Data
    @Published var journalEntries: [JournalEntryCD] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    // ID from JournalEntryCD might be optional, handle accordingly
    @Published var currentPlayingEntryId: UUID? = nil // Track which entry's audio is playing

    // MARK: - Services & Context (Dependencies)
    private let localAudioStorage: AudioStorageService // Keep for deleting/locating audio files
    private let viewContext: NSManagedObjectContext // Use context directly
    private var audioPlayer: AVAudioPlayer? // Use AVAudioPlayer for delegate methods

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(
        localAudioStorage: AudioStorageService = LocalAudioStorage(),
        viewContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) {
        self.localAudioStorage = localAudioStorage
        self.viewContext = viewContext
        super.init() // ✅ Always call super.init first

        // ✅ Safe call after full initialization
        Task { @MainActor in
            self.fetchEntries()
        }
    }



    // MARK: - Public Methods (Actions)

    /// Fetches journal entries directly from Core Data.
    func fetchEntries() {
        isLoading = true
        errorMessage = nil
        print("Fetching journal entries from Core Data...")

        // Perform fetch in the background, update UI on main thread
        Task.detached(priority: .userInitiated) {
            let request: NSFetchRequest<JournalEntryCD> = JournalEntryCD.fetchRequest()
            // Sort by creation date, newest first
            // Explicitly provide root type for key path
            request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntryCD.createdAt, ascending: false)]

            do {
                let entries = try self.viewContext.fetch(request)
                // Switch back to main actor to update published property
                await MainActor.run {
                    self.journalEntries = entries
                    self.isLoading = false
                    print("Fetched \(entries.count) entries.")
                }
            } catch {
                let errorDescription = "Failed to fetch journal entries: \(error.localizedDescription)"
                print(errorDescription)
                // Switch back to main actor to update published property
                await MainActor.run {
                    self.errorMessage = errorDescription
                    self.journalEntries = [] // Clear on error
                    self.isLoading = false
                }
            }
        }
    }

    /// Deletes a specific journal entry from Core Data and its associated audio file.
    func deleteEntry(_ entry: JournalEntryCD) {
        // Ensure ID is available for comparison and deletion
        guard let entryId = entry.id else {
            errorMessage = "Cannot delete entry with missing ID."
            return
        }

        if currentPlayingEntryId == entryId {
            stopAudio()
        }

        print("Attempting to delete entry ID: \(entryId)")
        viewContext.delete(entry)

        // Perform save and file deletion in the background
        Task.detached(priority: .userInitiated) {
            do {
                // 1. Save Core Data context - Requires await
                try await self.viewContext.save()
                print("Core Data entry deleted successfully.")

                // 2. Delete audio file from Local Storage using audioURL
                if let audioURLString = entry.audioURL, !audioURLString.isEmpty,
                   let audioFileURL = URL(string: audioURLString) { // Ensure it's a valid URL
                    do {
                        // Assuming deleteAudio(at:) is potentially async - Requires await
                        try await self.localAudioStorage.deleteAudio(at: audioFileURL)
                        print("Associated audio file deleted: \(audioFileURL.path)")
                    } catch {
                        print("Failed to delete audio file at '\(audioFileURL.path)': \(error.localizedDescription ?? "Unknown Error")")
                    }
                } else {
                    print("No valid associated audio file URL to delete for entry ID: \(entryId)")
                }

                // 3. Re-fetch on the main thread to update UI
                await MainActor.run {
                    self.fetchEntries() // Re-fetch to reflect deletion
                }

            } catch {
                let errorDescription = "Failed to save delete operation: \(error.localizedDescription)"
                print(errorDescription)
                self.viewContext.rollback() // Rollback Core Data changes on save error
                // Update UI on main thread
                await MainActor.run {
                    self.errorMessage = errorDescription
                    // Optionally re-fetch even on error to ensure consistency
                    // self.fetchEntries()
                }
            }
        }
    }

    /// Plays the audio associated with a journal entry.
    func playAudio(for entry: JournalEntryCD) {
        guard let entryId = entry.id else {
            errorMessage = "Cannot play audio for entry with missing ID."
            return
        }
        // Use the correct property name: audioURL
        guard let audioURLString = entry.audioURL, !audioURLString.isEmpty else {
            errorMessage = "Entry has no associated audio file URL string."
            return
        }
        guard let audioFileURL = URL(string: audioURLString) else {
             errorMessage = "Invalid audio URL format: \(audioURLString)"
             return
        }

        // No need to call localAudioStorage.getAudioURL if audioURL is the full path
        // let audioFileURL = localAudioStorage.getAudioURL(filename: audioFileName)

        // Check if the file actually exists locally using the URL directly
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            errorMessage = "Audio file not found at: \(audioFileURL.path)"
            return
        }

        stopAudio() // Stop any currently playing audio

        do {
            // Configure audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            // Initialize AVAudioPlayer
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.delegate = self // Set delegate to handle finish event
            audioPlayer?.play()
            currentPlayingEntryId = entryId
            print("Playing audio from local file: \(audioFileURL.path)")

        } catch {
             errorMessage = "Failed to start audio playback: \(error.localizedDescription)"
             print("Error starting playback: \(error)")
             currentPlayingEntryId = nil
             // Clean up audio session if activation failed but player init succeeded?
             try? AVAudioSession.sharedInstance().setActive(false)
        }
    }

    /// Stops the currently playing audio.
    func stopAudio() {
        guard audioPlayer != nil else { return } // Only stop if player exists

        audioPlayer?.stop()
        audioPlayer = nil
        currentPlayingEntryId = nil
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
        print("Audio stopped.")
    }

    // MARK: - AVAudioPlayerDelegate Methods

    // Ensure UI updates triggered by delegate methods happen on the Main Actor
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in // Dispatch to main actor
            print("Audio finished playing (successfully: \(flag))")
            // Reset state after audio finishes
            self.currentPlayingEntryId = nil
            self.audioPlayer = nil
            // Deactivate audio session
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to deactivate audio session after finishing: \(error.localizedDescription ?? "Unknown Error")")
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in // Dispatch to main actor
            let errorDesc = error?.localizedDescription ?? "Unknown error"
            self.errorMessage = "Audio playback decoding error: \(errorDesc)"
            print("Audio decode error: \(errorDesc)")
            self.currentPlayingEntryId = nil
            self.audioPlayer = nil
            // Deactivate audio session on error too
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    // MARK: - Deinitialization
    deinit {
        // Ensure audio player is stopped and resources released
        // Accessing self properties directly in deinit is fine
        if audioPlayer != nil {
            audioPlayer?.stop()
            audioPlayer = nil
        }
        print("HistoryViewModel deinitialized.")
    }
} 
