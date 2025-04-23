import Foundation
import CoreData

// Protocol defining the storage operations
protocol JournalStorage {
    func saveEntry(id: UUID, entryText: String, audioURL: URL, createdAt: Date) throws
    func fetchAllEntries() throws -> [JournalEntry] // Return the DTO struct
    func fetchEntry(byId id: UUID) -> JournalEntryCD? // Fetch the Managed Object
    func deleteEntry(id: UUID) throws
    func saveFollowUp(question: String, for entry: JournalEntryCD) throws // Add method for follow-up
}

class CoreDataStorage: JournalStorage {
    private let context: NSManagedObjectContext

    // Initialize with the shared persistence controller's context
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    /// Saves a new journal entry to Core Data.
    /// - Parameters:
    ///   - id: The unique identifier for the entry.
    ///   - entryText: The transcribed text.
    ///   - audioURL: The file URL of the saved audio recording.
    ///   - createdAt: The timestamp when the entry was created.
    /// - Throws: An error if saving fails.
    func saveEntry(id: UUID = UUID(), entryText: String, audioURL: URL, createdAt: Date = Date()) throws {
        // Create a new managed object instance
        let newEntryCD = JournalEntryCD(context: context) // Use the auto-generated class name
        newEntryCD.id = id
        newEntryCD.entryText = entryText
        newEntryCD.audioURL = audioURL.absoluteString // Store URL as String
        newEntryCD.createdAt = createdAt

        // Save the context
        do {
            try context.save()
            print("Core Data entry saved successfully: ID \(id)")
        } catch {
            print("Error saving Core Data entry: \(error.localizedDescription)")
            // Optionally, roll back changes if needed
            // context.rollback()
            throw error // Re-throw the error for upstream handling
        }
    }

    /// Fetches all journal entries from Core Data, sorted by creation date descending.
    /// - Returns: An array of JournalEntry data transfer objects.
    /// - Throws: An error if fetching fails.
    func fetchAllEntries() throws -> [JournalEntry] {
        // Create a fetch request for the JournalEntryCD entity
        let fetchRequest: NSFetchRequest<JournalEntryCD> = JournalEntryCD.fetchRequest()

        // Add a sort descriptor to order by date, newest first
        let sortDescriptor = NSSortDescriptor(keyPath: \JournalEntryCD.createdAt, ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            // Execute the fetch request
            let results = try context.fetch(fetchRequest)

            // Map the NSManagedObject results to the JournalEntry DTO struct
            let entries = results.compactMap { entryCD -> JournalEntry? in
                // Ensure required fields are present
                guard let id = entryCD.id,
                      let text = entryCD.entryText,
                      let urlString = entryCD.audioURL,
                      let date = entryCD.createdAt else { return nil }
                
                // Note: We assume audioURL stored is a valid file URL string
                // No userId needed anymore for the local struct
                return JournalEntry(id: id, entryText: text, audioURL: urlString, createdAt: date, userId: "") // userId is deprecated
            }
            print("Fetched \(entries.count) entries from Core Data.")
            return entries
        } catch {
            print("Error fetching Core Data entries: \(error.localizedDescription)")
            throw error // Re-throw the error
        }
    }

    /// Fetches a single JournalEntryCD managed object by its UUID.
    /// - Parameter id: The UUID of the entry to fetch.
    /// - Returns: The `JournalEntryCD` object if found, otherwise `nil`.
    func fetchEntry(byId id: UUID) -> JournalEntryCD? {
        let fetchRequest: NSFetchRequest<JournalEntryCD> = JournalEntryCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            return results.first // Return the managed object itself
        } catch {
            print("Error fetching Core Data entry by ID \(id): \(error.localizedDescription)")
            return nil
        }
    }

    /// Saves a new follow-up question linked to a specific journal entry.
    /// - Parameters:
    ///   - question: The text of the follow-up question.
    ///   - entry: The `JournalEntryCD` managed object to link the follow-up to.
    /// - Throws: An error if saving fails.
    func saveFollowUp(question: String, for entry: JournalEntryCD) throws {
        let newFollowUp = FollowUpCD(context: context) // Assuming FollowUpCD is your entity name
        newFollowUp.id = UUID()
        newFollowUp.createdAt = Date()
        newFollowUp.question = question
        newFollowUp.answer = "" // Initialize answer as empty
        newFollowUp.journalEntry = entry // Set the relationship

        // Add the follow-up to the entry's set (if inverse relationship is set up)
        entry.addToFollowups(newFollowUp) // Assumes a to-many relationship named 'followups'

        do {
            try context.save()
            print("Follow-up question saved successfully for entry: \(entry.id?.uuidString ?? "N/A")")
        } catch {
            print("Error saving follow-up question: \(error.localizedDescription)")
            context.rollback() // Roll back if save fails
            throw error
        }
    }

    /// Deletes a specific journal entry from Core Data based on its ID.
    /// - Parameter id: The UUID of the entry to delete.
    /// - Throws: An error if fetching or deleting fails.
    func deleteEntry(id: UUID) throws {
        // Create a fetch request to find the entry with the matching ID
        let fetchRequest: NSFetchRequest<JournalEntryCD> = JournalEntryCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1 // We only need one result

        do {
            // Fetch the specific entry
            let results = try context.fetch(fetchRequest)
            if let entryToDelete = results.first {
                // Delete the object from the context
                context.delete(entryToDelete)
                // Save the context to persist the deletion
                try context.save()
                print("Core Data entry deleted successfully: ID \(id)")
            } else {
                print("Core Data entry with ID \(id) not found for deletion.")
                // Optionally throw a specific 'not found' error
            }
        } catch {
            print("Error deleting Core Data entry with ID \(id): \(error.localizedDescription)")
            throw error // Re-throw the error
        }
    }
} 