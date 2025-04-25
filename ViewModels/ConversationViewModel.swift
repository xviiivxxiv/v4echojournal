import Foundation
import CoreData
import Combine
import SwiftUI

@MainActor
class ConversationViewModel: ObservableObject {
    // Primarily holds the entry data now
    let journalEntry: JournalEntryCD
    // Context might not be needed here anymore if view passes it to controller
    // private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(journalEntry: JournalEntryCD, context: NSManagedObjectContext) {
        self.journalEntry = journalEntry
        // self.context = context // Context no longer needed here

        print("ConversationViewModel initialized for entry ID: \(journalEntry.id?.uuidString ?? "N/A")")
        // REMOVED: Controller initialization and startLoop call
    }
}
