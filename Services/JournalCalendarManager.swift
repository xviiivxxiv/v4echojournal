import Foundation
import CoreData

class JournalCalendarManager {

    /// Filters all unique journal entry dates (normalized to start of day) for a specific month and year
    /// from a provided list of all entries, returning a map from Date to the first JournalEntryCD for that date.
    /// - Parameters:
    ///   - month: A Date object representing any day within the desired month.
    ///   - allEntries: An array of all `JournalEntryCD` objects fetched from Core Data.
    ///   - context: The NSManagedObjectContext (currently unused but kept for potential future needs like specific calendar configurations).
    /// - Returns: A Dictionary of [Date: JournalEntryCD], where each key is the start of a day in the given month 
    ///            that has at least one journal entry, and the value is the first such entry found for that day.
    func getJournalEntriesMapForMonth(for month: Date, fromAllEntries allEntries: [JournalEntryCD], using context: NSManagedObjectContext) -> [Date: JournalEntryCD] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            print("Error: Could not calculate month interval for: \(month).")
            return [:]
        }

        let startDate = monthInterval.start
        let endDate = monthInterval.end // This is the start of the *next* month

        var entryMapInMonth: [Date: JournalEntryCD] = [:]

        // Sort entries by createdAt to ensure consistency if multiple entries fall on the same day (optional, but good practice)
        let sortedEntries = allEntries.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }

        for entry in sortedEntries {
            if let createdAt = entry.createdAt {
                // Check if the entry date falls within the displayed month interval
                if createdAt >= startDate && createdAt < endDate {
                    let startOfDay = calendar.startOfDay(for: createdAt)
                    // If an entry for this day hasn't been added yet, add it.
                    // This ensures we take the first entry of the day if multiple exist.
                    if entryMapInMonth[startOfDay] == nil {
                        entryMapInMonth[startOfDay] = entry
                    }
                }
            }
        }
        
        print("JournalCalendarManager: Created map with \(entryMapInMonth.count) unique entry days for month starting \(startDate).")
        return entryMapInMonth
    }
    
    // The markEntry(date: Date) method described in the prompt seems redundant.
    // The calendar should refresh its data based on existing CoreData entries when the view appears or month changes.
    // Actual saving of JournalEntryCD objects is handled by CoreDataStorage.
} 