import Foundation
import CoreData

// Protocol defining the storage operations
protocol JournalStorage {
    func saveEntry(id: UUID, entryText: String, audioURL: URL, createdAt: Date, keywords: String?) throws
    func fetchAllEntries() throws -> [JournalEntry] // Return the DTO struct
    func fetchEntry(byId id: UUID) -> JournalEntryCD? // Fetch the Managed Object
    func deleteEntry(id: UUID) throws
    func saveFollowUp(question: String, for entry: JournalEntryCD) throws // Add method for follow-up
    func saveMessage(for entry: JournalEntryCD, text: String, sender: String, timestamp: Date) throws
    func savePhoto(for entry: JournalEntryCD, imageData: Data, caption: String?, timestamp: Date) throws
    func updateKeywordsAndHeadline(for entry: JournalEntryCD, keywords: [String], headline: String?) throws // New method signature
    func saveIdentifiedFeelings(for entry: JournalEntryCD, feelings: [(name: String, category: String)]) throws // Added
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
    ///   - keywords: Optional comma-separated string of keywords.
    /// - Throws: An error if saving fails.
    func saveEntry(id: UUID = UUID(), entryText: String, audioURL: URL, createdAt: Date = Date(), keywords: String? = nil) throws {
        // Create a new managed object instance
        let newEntryCD = JournalEntryCD(context: context) // Use the auto-generated class name
        newEntryCD.id = id
        newEntryCD.entryText = entryText
        newEntryCD.audioURL = audioURL.absoluteString // Store URL as String
        newEntryCD.createdAt = createdAt
        newEntryCD.keywords = keywords // Assign keywords

        // --- Add logic for highestStreak --- 
        let streakManager = StreakManager()
        var allEntries: [JournalEntryCD] = [] // To hold previously saved entries

        let fetchRequest: NSFetchRequest<JournalEntryCD> = JournalEntryCD.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntryCD.createdAt, ascending: false)]
        // Exclude the current unsaved newEntryCD from this initial fetch if it's already in the context's insertedObjects
        // However, it's safer to fetch all and then construct the list for current streak calculation carefully.
        do {
            allEntries = try context.fetch(fetchRequest)
        } catch {
            print("Error fetching existing entries for streak calculation: \(error.localizedDescription)")
            // Decide if this error should prevent saving or just save without streak calculation.
            // For now, we'll proceed and highestStreak might be 0 or based on an empty list.
        }

        // Calculate current streak *as if* the new entry is part of the set
        // To do this, we consider a list that includes the new entry's date along with other entries.
        // A simple way is to pass all entries (including the new one once it's part of 'allEntries' effectively after this save)
        // Or, more accurately for `calculateCurrentStreak` as written:
        // Create a temporary list of entries for current streak calculation that includes the new one.
        // The `StreakManager.calculateCurrentStreak` expects an array of JournalEntryCD.
        // Since newEntryCD is not yet saved and might not be in `allEntries` from fetch, we add it to a temporary list.
        var entriesForCurrentStreakCalc = allEntries
        // Ensure the new entry is only considered once and correctly.
        // If `newEntryCD` is already in `allEntries` (e.g., if fetch includes uncommitted changes, though unlikely with default fetch), avoid duplication.
        if !allEntries.contains(where: { $0.objectID == newEntryCD.objectID }) {
             entriesForCurrentStreakCalc.append(newEntryCD)
        }
        // And sort it again because the new entry might not be in the correct order yet
        entriesForCurrentStreakCalc.sort { $0.createdAt ?? Date.distantPast > $1.createdAt ?? Date.distantPast }

        let currentStreak = streakManager.calculateCurrentStreak(from: entriesForCurrentStreakCalc)
        
        // Get overall highest streak from *previously existing* entries (before this new one)
        let overallHighestStreakBeforeThisEntry = streakManager.getOverallHighestStreak(from: allEntries)
        
        newEntryCD.highestStreak = Int16(max(currentStreak, overallHighestStreakBeforeThisEntry))
        // --- End logic for highestStreak ---

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

    /// Saves a new conversation message linked to a specific journal entry.
    /// - Parameters:
    ///   - entry: The `JournalEntryCD` managed object to link the message to.
    ///   - text: The content of the message.
    ///   - sender: The sender of the message (e.g., "user", "ai").
    ///   - timestamp: The time the message was sent.
    /// - Throws: An error if saving fails.
    func saveMessage(for entry: JournalEntryCD, text: String, sender: String, timestamp: Date) throws {
        let newMessage = ConversationMessage(context: context)
        newMessage.id = UUID()
        newMessage.text = text
        newMessage.sender = sender
        newMessage.timestamp = timestamp
        newMessage.journalEntry = entry // Set the to-one relationship

        // Add the message to the entry's ordered set of messages
        // This assumes 'messages' is the name of the to-many relationship in JournalEntryCD
        // and that it's an NSOrderedSet.
        entry.addToMessages(newMessage)

        do {
            try context.save()
            print("Conversation message saved successfully for entry: \(entry.id?.uuidString ?? "N/A")")
        } catch {
            print("Error saving conversation message: \(error.localizedDescription)")
            context.rollback() // Roll back if save fails
            throw error
        }
    }

    /// Saves a new photo linked to a specific journal entry.
    /// - Parameters:
    ///   - entry: The `JournalEntryCD` managed object to link the photo to.
    ///   - imageData: The raw data of the photo.
    ///   - caption: An optional caption for the photo.
    ///   - timestamp: The time the photo was added.
    /// - Throws: An error if saving fails.
    func savePhoto(for entry: JournalEntryCD, imageData: Data, caption: String?, timestamp: Date = Date()) throws {
        let newPhoto = JournalPhoto(context: context)
        newPhoto.id = UUID()
        newPhoto.imageData = imageData
        newPhoto.caption = caption
        newPhoto.timestamp = timestamp
        newPhoto.journalEntry = entry // Set the to-one relationship

        // Add the photo to the entry's ordered set of photos
        // This assumes 'photos' is the name of the to-many relationship in JournalEntryCD
        // and that it's an NSOrderedSet.
        entry.addToPhotos(newPhoto)

        do {
            try context.save()
            print("Photo saved successfully for entry: \(entry.id?.uuidString ?? "N/A")")
        } catch {
            print("Error saving photo: \(error.localizedDescription)")
            context.rollback() // Roll back if save fails
            throw error
        }
    }

    /// Updates the keywords and headline for an existing journal entry.
    /// - Parameters:
    ///   - entry: The `JournalEntryCD` managed object to update.
    ///   - keywords: An array of keyword strings.
    ///   - headline: An optional headline string.
    /// - Throws: An error if saving fails.
    func updateKeywordsAndHeadline(for entry: JournalEntryCD, keywords: [String], headline: String?) throws {
        entry.keywords = keywords.joined(separator: ", ")
        entry.headline = headline // Save the new headline
        
        do {
            try context.save()
            print("Keywords and headline updated successfully for entry: \(entry.id?.uuidString ?? "N/A")")
        } catch {
            print("Error updating keywords and headline: \(error.localizedDescription)")
            context.rollback()
            throw error
        }
    }

    /// Saves identified feelings for a journal entry. This will clear existing identified feelings for the entry before saving new ones.
    /// - Parameters:
    ///   - entry: The `JournalEntryCD` managed object to associate feelings with.
    ///   - feelings: An array of tuples, each containing the feeling name and category.
    /// - Throws: An error if saving fails.
    func saveIdentifiedFeelings(for entry: JournalEntryCD, feelings: [(name: String, category: String)]) throws {
        // Clear existing identified feelings for this entry to prevent duplicates if re-processing
        if let existingFeelings = entry.identifiedFeelings as? NSSet {
            for feeling in existingFeelings {
                if let feelingToDelete = feeling as? IdentifiedFeelingCD {
                    context.delete(feelingToDelete)
                }
            }
        }
        entry.identifiedFeelings = NSOrderedSet() // Reset to empty ordered set

        // Add new feelings
        for feelingData in feelings {
            let newFeeling = IdentifiedFeelingCD(context: context)
            newFeeling.id = UUID()
            newFeeling.name = feelingData.name
            newFeeling.category = feelingData.category
            newFeeling.timestamp = Date()
            newFeeling.journalEntry = entry // Link to the journal entry
            entry.addToIdentifiedFeelings(newFeeling) // Add to the ordered set
        }

        do {
            try context.save()
            print("Identified feelings (\(feelings.count)) saved successfully for entry: \(entry.id?.uuidString ?? "N/A")")
        } catch {
            print("Error saving identified feelings: \(error.localizedDescription)")
            context.rollback()
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