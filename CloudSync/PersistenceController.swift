import CoreData
import CloudKit
import Combine

/// `PersistenceController` handles Core Data + CloudKit setup.
class PersistenceController: ObservableObject {
    /// Shared singleton instance
    static let shared = PersistenceController()

    /// The main Core Data container with CloudKit support
    let container: NSPersistentCloudKitContainer

    /// Standard initializer, defaulting to persistent store
    private init(inMemory: Bool = false) {
        // ✅ This must match the name of your .xcdatamodeld file
        container = NSPersistentCloudKitContainer(name: "EchoJournal")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // Load the Core Data store
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("❌ Failed to load Core Data store: \(error), \(error.userInfo)")
            } else {
                print("✅ Core Data loaded from: \(storeDescription.url?.absoluteString ?? "unknown")")
            }
        }

        // Enable iCloud sync and automatic merge handling
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Preview-friendly mock Core Data setup
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        // Add sample data only if model is available
        for i in 0..<5 {
            let newItem = JournalEntryCD(context: viewContext)
            newItem.id = UUID()
            newItem.createdAt = Date().addingTimeInterval(-Double(i * 3600 * 24))
            newItem.entryText = "Sample entry \(i)"
            newItem.audioURL = "file:///preview/audio_\(i).m4a"
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("❌ Preview context failed to save: \(nsError), \(nsError.userInfo)")
        }
        }
        #endif

        return controller
    }()

    /// Save context changes, with error handling
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("❌ SaveContext failed: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

