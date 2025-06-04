import Foundation
import CoreData

class JournalCalendarManager {

    /// Filters all unique journal entry dates (normalized to start of day) for a specific month and year
    /// from a provided list of all entries.
    /// - Parameters:
    ///   - month: A Date object representing any day within the desired month.
    ///   - allEntries: An array of all `JournalEntryCD` objects fetched from Core Data.
    ///   - context: The NSManagedObjectContext (currently unused but kept for potential future needs like specific calendar configurations).
    /// - Returns: A Set of Date objects, each representing the start of a day in the given month that has at least one journal entry.
    func getJournalEntryDays(for month: Date, fromAllEntries allEntries: [JournalEntryCD], using context: NSManagedObjectContext) -> Set<Date> {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            print("Error: Could not calculate month interval for: \(month).")
            return []
        }

        let startDate = monthInterval.start
        let endDate = monthInterval.end // This is the start of the *next* month

        var entryDatesInMonth: Set<Date> = []

        for entry in allEntries {
            if let createdAt = entry.createdAt {
                // Check if the entry date falls within the displayed month interval
                if createdAt >= startDate && createdAt < endDate {
                    let startOfDay = calendar.startOfDay(for: createdAt)
                    entryDatesInMonth.insert(startOfDay)
                }
            }
        }
        
        print("JournalCalendarManager: Filtered \(entryDatesInMonth.count) unique entry days for month starting \(startDate) from provided entries.")
        return entryDatesInMonth
    }
    
    // The markEntry(date: Date) method described in the prompt seems redundant.
    // The calendar should refresh its data based on existing CoreData entries when the view appears or month changes.
    // Actual saving of JournalEntryCD objects is handled by CoreDataStorage.
} 