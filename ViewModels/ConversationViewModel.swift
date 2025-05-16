import Foundation
import CoreData
import Combine
import SwiftUI

@MainActor
class ConversationViewModel: ObservableObject {
    // Published properties
    @Published var text: String = ""
    
    // Core Data properties
    let journalEntry: JournalEntryCD
    // Context might not be needed here anymore if view passes it to controller
    // private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(journalEntry: JournalEntryCD, context: NSManagedObjectContext) {
        self.journalEntry = journalEntry
        self.text = journalEntry.entryText ?? ""
        // self.context = context // Context no longer needed here

        print("ConversationViewModel initialized for entry ID: \(journalEntry.id?.uuidString ?? "N/A")")
        // REMOVED: Controller initialization and startLoop call

        // Set up text binding to automatically update entry
        $text
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] newText in
                self?.updateEntryText(newText)
            }
            .store(in: &cancellables)
    }

    private func updateEntryText(_ newText: String) {
        journalEntry.entryText = newText
        autoTagMoodIfNeeded(for: journalEntry)
        
        do {
            try journalEntry.managedObjectContext?.save()
            print("✅ Journal entry text updated successfully")
        } catch {
            print("❌ Error saving context: \(error)")
        }
    }

    // MARK: - Mood Auto-Tagging Logic

    private func autoTagMoodIfNeeded(for entry: JournalEntryCD) {
        // Check if mood is already set or if entry text is missing
        guard entry.mood?.isEmpty != false, let text = entry.entryText, !text.isEmpty else {
            // Mood already set or no text to analyze
            print("🧠 Mood Auto-Tag: Skipped (Mood: \(entry.mood ?? "nil"), Text Empty: \(entry.entryText?.isEmpty ?? true))")
            return
        }

        print("🧠 Mood Auto-Tag: Analyzing text for mood...")
        let lowercasedText = text.lowercased()
        var detectedMood: String? = nil

        // Simple keyword matching (expand keywords as needed)
        let sadKeywords = ["sad", "crying", "depressed", "unhappy", "down", "lonely"]
        let anxiousKeywords = ["anxious", "anxiety", "worried", "stress", "stressed", "overwhelmed", "nervous"]
        let angryKeywords = ["angry", "mad", "frustrated", "irritated", "pissed"]
        let happyKeywords = ["happy", "joy", "excited", "grateful", "pleased", "good", "great", "wonderful"]
        let calmKeywords = ["calm", "peaceful", "relaxed", "content", "serene"]
        let tiredKeywords = ["tired", "exhausted", "sleepy", "drained"]

        // Check in a specific order (e.g., negative emotions first)
        if containsKeyword(from: anxiousKeywords, in: lowercasedText) { detectedMood = "Anxious" }
        else if containsKeyword(from: angryKeywords, in: lowercasedText) { detectedMood = "Angry" }
        else if containsKeyword(from: sadKeywords, in: lowercasedText) { detectedMood = "Sad" }
        else if containsKeyword(from: tiredKeywords, in: lowercasedText) { detectedMood = "Tired" }
        else if containsKeyword(from: happyKeywords, in: lowercasedText) { detectedMood = "Happy" }
        else if containsKeyword(from: calmKeywords, in: lowercasedText) { detectedMood = "Calm" }

        if let mood = detectedMood {
            entry.mood = mood
            print("🧠 Mood Auto-Tag: Detected and set mood to '\(mood)'")
        } else {
            print("🧠 Mood Auto-Tag: No specific mood keywords detected.")
        }
        // Future Enhancement: Could call GPTService here for more nuanced mood detection if simple keywords aren't sufficient.
        // Task {
        //     entry.mood = try? await GPTService.shared.detectMood(from: text)
        // }
    }

    private func containsKeyword(from keywords: [String], in text: String) -> Bool {
        for keyword in keywords {
            if text.contains(keyword) {
                return true
            }
        }
        return false
    }

    // --- Example of where to call it (ADJUST THIS based on your actual saving function) ---
    // Find your function that saves the JournalEntryCD, e.g.:
    /*
    func saveJournalEntry(text: String, keywords: String?, mood: String?) {
        // ... (get or create entry: JournalEntryCD)
        entry.entryText = text
        entry.keywords = keywords // User-provided keywords
        entry.mood = mood // User-provided mood
        entry.createdAt = Date()
        entry.id = entry.id ?? UUID() // Ensure ID exists
        
        // *** Call auto-tagging BEFORE saving ***
        autoTagMoodIfNeeded(for: entry)

        do {
            try viewContext.save()
            print("✅ Journal entry saved successfully (ID: \(entry.id!))")
            // ... (reset state, etc.)
        } catch {
            print("❌ Error saving context: \(error)")
            // ... (handle error)
        }
    }
    */
} 
