import Foundation
import CoreData

struct DataManager {
    
    /// Erases all user-generated data from the application.
    /// This includes all Core Data entries, Keychain passcodes, and UserDefaults settings.
    static func eraseAllData() {
        print("--- Starting Data Erasure Process ---")
        
        // 1. Delete all Core Data entries
        eraseCoreData()
        
        // 2. Delete the passcode from the Keychain
        if KeychainService.deletePasscode() {
            print("✅ Keychain passcode deleted successfully.")
        } else {
            print("⚠️ Keychain deletion failed, but continuing.")
        }
        
        // 3. Reset all UserDefaults
        resetUserDefaults()
        
        print("--- Data Erasure Process Complete ---")
    }
    
    /// Deletes all records from Core Data entities.
    private static func eraseCoreData() {
        let context = PersistenceController.shared.container.viewContext
        // Add all of your Core Data entity names here
        let entityNames = ["JournalEntryCD", "FollowUpCD", "FutureEntryCD"] // Make sure to include all entities
        
        for entityName in entityNames {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(batchDeleteRequest)
                try context.save()
                print("✅ All records from '\(entityName)' have been deleted.")
            } catch {
                print("❌ Error deleting records from '\(entityName)': \(error.localizedDescription)")
            }
        }
    }
    
    /// Removes all data from the app's UserDefaults suite.
    private static func resetUserDefaults() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            print("✅ All UserDefaults have been reset.")
        } else {
            print("⚠️ Could not find bundle ID to reset UserDefaults.")
        }
    }
} 