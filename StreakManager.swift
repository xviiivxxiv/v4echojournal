import Foundation
import CoreData

class StreakManager {

    let predefinedMilestones: [Int] = [1, 3, 7, 10, 14, 21, 30, 50, 100]

    /// Calculates the current streak of consecutive days with journal entries.
    func calculateCurrentStreak(from entries: [JournalEntryCD]) -> Int {
        guard !entries.isEmpty else { return 0 }

        // Sort entries by creation date, newest first
        let sortedEntries = entries.sorted { $0.createdAt ?? Date.distantPast > $1.createdAt ?? Date.distantPast }

        var currentStreak = 0
        var currentDate = Date() // Today

        // Check if the most recent entry is from today
        if let firstEntryDate = sortedEntries.first?.createdAt, Calendar.current.isDateInToday(firstEntryDate) {
            currentStreak = 1
            // Start checking from yesterday for the rest of the streak
            currentDate = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        } else if let firstEntryDate = sortedEntries.first?.createdAt, Calendar.current.isDateInYesterday(firstEntryDate) {
            // If the most recent entry is yesterday, and nothing today, streak is 0, but we start checking from yesterday
             currentStreak = 0 // Streak broken if no entry today
             // This path means no entry today. If latest entry is yesterday, current streak IS 0 unless it's the *only* entry.
             // The loop below will correctly determine the streak *ending* yesterday.
             // If the latest entry is yesterday, we start checking from 2 days ago.
             // No, if latest is yesterday, current streak is 0. Loop needs to check from sortedEntries[0]
        } else {
            // No entry today or yesterday for the most recent one
            return 0
        }
        
        // If only one entry and it's today, streak is 1 (handled above)
        if currentStreak == 1 && sortedEntries.count == 1 {
            return 1
        }

        // If streak starts today, we look for entries from yesterday onwards in the rest of the list
        let entriesToCheck = (currentStreak == 1) ? Array(sortedEntries.dropFirst()) : sortedEntries
        
        var expectedDate = currentDate // This will be yesterday if streak started today, or today if no entry today

        for entry in entriesToCheck {
            guard let entryDate = entry.createdAt else { continue }
            if Calendar.current.isDate(entryDate, inSameDayAs: expectedDate) {
                currentStreak += (currentStreak == 0 && Calendar.current.isDateInYesterday(entryDate)) ? 1 : (currentStreak > 0 ? 1 : 0)
                if currentStreak == 0 && Calendar.current.isDateInYesterday(entryDate) { // First day of streak is yesterday
                     currentStreak = 1
                }
                expectedDate = Calendar.current.date(byAdding: .day, value: -1, to: expectedDate)!
            } else if Calendar.current.compare(entryDate, to: expectedDate, toGranularity: .day) == .orderedAscending {
                // Entry is older than expected, means a gap
                break
            }
            // If entryDate is more recent than expectedDate but not the same day, it's a duplicate for a day already counted or a future entry (ignore)
        }
        
        // Refined logic for streak calculation:
        // Simplified approach:
        // 1. Get unique days with entries, sorted descending.
        // 2. Check if today or yesterday is the first unique day.
        // 3. Iterate backwards checking for consecutive days.

        let uniqueEntryDays = Set(sortedEntries.compactMap { entry -> Date? in
            guard let date = entry.createdAt else { return nil }
            return Calendar.current.startOfDay(for: date)
        }).sorted(by: >) // Newest first

        guard let latestEntryDay = uniqueEntryDays.first else { return 0 }

        var streak = 0
        var loopDate: Date

        if Calendar.current.isDateInToday(latestEntryDay) {
            streak = 1
            loopDate = Calendar.current.date(byAdding: .day, value: -1, to: latestEntryDay)! // Start checking from yesterday
        } else if Calendar.current.isDateInYesterday(latestEntryDay) {
            streak = 1 // Streak of 1 ending yesterday
            loopDate = Calendar.current.date(byAdding: .day, value: -1, to: latestEntryDay)! // Start checking from day before yesterday
        } else {
            return 0 // No entry today or yesterday
        }

        if uniqueEntryDays.count > 1 {
            for i in 1..<uniqueEntryDays.count {
                if uniqueEntryDays[i] == loopDate {
                    streak += 1
                    loopDate = Calendar.current.date(byAdding: .day, value: -1, to: loopDate)!
                } else {
                    break // Streak broken
                }
            }
        }
        return streak
    }

    /// Retrieves the overall highest streak recorded.
    /// Assumes `highestStreak` is stored on each `JournalEntryCD` and the latest entry holds the current max.
    func getOverallHighestStreak(from entries: [JournalEntryCD]) -> Int {
        // Sort entries by creation date, newest first
        let sortedEntries = entries.sorted { $0.createdAt ?? Date.distantPast > $1.createdAt ?? Date.distantPast }
        return Int(sortedEntries.first?.highestStreak ?? 0)
    }
    
    /// Calculates the next milestone based on the current streak.
    func calculateNextMilestone(currentStreak: Int) -> Int {
        if let next = predefinedMilestones.first(where: { $0 > currentStreak }) {
            return next
        }
        // If current streak exceeds all predefined milestones, maybe return the last one or currentStreak + 1
        return predefinedMilestones.last ?? currentStreak + 7 // Default to a week after the last milestone
    }
} 