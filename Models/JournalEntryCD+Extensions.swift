// JournalEntryCD+Extensions.swift

import Foundation
import CoreData // Make sure CoreData is imported

extension JournalEntryCD {

    /// Calculates the total word count of all messages sent by the "user"
    /// associated with this journal entry.
    var wordCountOfUserMessages: Int {
        guard let messages = self.messages as? NSOrderedSet else {
            // If there are no messages or the relationship is not set up as expected
            print("⚠️ JournalEntryCD (\(self.id?.uuidString ?? "Unknown ID")): No messages found or messages relationship is not an NSOrderedSet. Returning 0 for user word count.")
            return 0
        }

        let userMessagesText = (messages.array as? [ConversationMessage] ?? [])
            .filter { $0.sender == "user" } // Ensure "user" is your consistent identifier for the user
            .compactMap { $0.text }

        let totalWords = userMessagesText.reduce(0) { count, text in
            count + text.split { $0.isWhitespace || $0.isNewline }.count
        }
        
        // Optional: Add a log to see the calculation for a specific entry
        // print("ℹ️ JournalEntryCD (\(self.id?.uuidString ?? "Unknown ID")): Calculated wordCountOfUserMessages = \(totalWords)")
        
        return totalWords
    }

    /// Calculates the word count of the initial `entryText` field.
    var wordCountOfInitialEntryText: Int {
        let count = self.entryText?.split { $0.isWhitespace || $0.isNewline }.count ?? 0
        // print("ℹ️ JournalEntryCD (\(self.id?.uuidString ?? "Unknown ID")): Calculated wordCountOfInitialEntryText = \(count)")
        return count
    }

    // Helper to get an emoji asset name for an emotion category
    // This mirrors the logic in JournalEntryDetailView and DateInteractionModalView for consistency
    private func emojiAssetNameForFeelingCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "great": return "emoji_great"
        case "good": return "emoji_good"
        case "fine": return "emoji_fine"
        case "bad": return "emoji_bad"
        case "terrible": return "emoji_terrible"
        default: return "questionmark.circle" // SF Symbol as a fallback for unknown category
        }
    }

    /// Determines the overall feeling emoji asset name for the calendar display.
    /// Prioritizes userSelectedFeelingCategory, then falls back to the first identified feeling.
    var feelingEmojiAssetName: String? {
        if let userSelectedCategory = self.userSelectedFeelingCategory, !userSelectedCategory.isEmpty {
            return emojiAssetNameForFeelingCategory(userSelectedCategory)
        }
        // Fallback to identified feelings if no user selection
        guard let feelingsSet = self.identifiedFeelings as? NSOrderedSet,
              let feelings = feelingsSet.array as? [IdentifiedFeelingCD],
              let firstFeelingWithCategory = feelings.first(where: { $0.category != nil && !$0.category!.isEmpty }) else {
            // If no feelings or categories, no specific emoji to show
            return nil 
        }
        return emojiAssetNameForFeelingCategory(firstFeelingWithCategory.category!)
    }

    // You could add other useful computed properties here in the future, e.g.:
    // var totalConversationMessagesCount: Int {
    //     return (self.messages as? NSOrderedSet)?.count ?? 0
    // }
    //
    // var aiMessagesCount: Int {
    //     guard let messages = self.messages as? NSOrderedSet else { return 0 }
    //     return (messages.array as? [ConversationMessage] ?? []).filter { $0.sender == "ai" }.count
    // }
} 