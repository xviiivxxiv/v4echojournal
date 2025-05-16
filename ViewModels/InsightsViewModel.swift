import SwiftUI
import CoreData
import Combine

@MainActor // Ensure UI updates happen on the main thread
class InsightsViewModel: ObservableObject {

    @Published var topMoods: [String] = []
    @Published var commonKeywords: [String] = []
    @Published var reflectionSummary: String = "Analyzing your recent entries..."
    @Published var weeklyEntryCount: Int = 0
    @Published var isLoading: Bool = false

    private var viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchAndProcessInsights()
    }

    func fetchAndProcessInsights() {
        isLoading = true
        print("🧠 InsightsViewModel: Fetching and processing insights...")

        // Perform Core Data fetch asynchronously
        Task {
            let request: NSFetchRequest<JournalEntryCD> = JournalEntryCD.fetchRequest()
            // Fetch entries from the last 7 days for weekly summary
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            request.predicate = NSPredicate(format: "createdAt >= %@", oneWeekAgo as NSDate)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntryCD.createdAt, ascending: false)]

            do {
                let entries = try viewContext.fetch(request)
                print("🧠 InsightsViewModel: Fetched \(entries.count) entries from the last week.")
                processEntries(entries)
                self.weeklyEntryCount = entries.count // Set weekly count

                // Fetch all entries for overall insights (moods, keywords)
                let allEntriesRequest: NSFetchRequest<JournalEntryCD> = JournalEntryCD.fetchRequest()
                let allEntries = try viewContext.fetch(allEntriesRequest)
                print("🧠 InsightsViewModel: Fetched \(allEntries.count) total entries for analysis.")
                processOverallInsights(allEntries)

            } catch {
                print("❌ InsightsViewModel: Failed to fetch journal entries: \(error)")
                self.reflectionSummary = "Could not load insights. Error fetching data."
            }
            isLoading = false
        }
    }

    private func processEntries(_ entries: [JournalEntryCD]) {
        // Simple summary logic (can be expanded)
        if entries.isEmpty {
            self.reflectionSummary = "No entries found in the last week to generate insights."
        } else {
            // Find most common mood in the last week
            let weeklyMoods = entries.compactMap { $0.mood?.lowercased() }.filter { !$0.isEmpty }
            let weeklyMoodCounts = weeklyMoods.reduce(into: [:]) { counts, mood in counts[mood, default: 0] += 1 }
            let mostFrequentWeeklyMood = weeklyMoodCounts.max { $0.value < $1.value }?.key

            if let mood = mostFrequentWeeklyMood {
                 self.reflectionSummary = "Most journaled mood this week: \(mood.capitalized). You logged \(weeklyEntryCount) entries."
            } else if weeklyEntryCount > 0 {
                 self.reflectionSummary = "You logged \(weeklyEntryCount) entries this week. Keep journaling to unlock mood insights!"
            } else {
                 self.reflectionSummary = "Start journaling this week to discover insights about your moods and themes."
            }
        }
    }

    private func processOverallInsights(_ entries: [JournalEntryCD]) {
        guard !entries.isEmpty else {
            self.topMoods = []
            self.commonKeywords = []
            return
        }

        // Process Moods
        let allMoods = entries.compactMap { $0.mood?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let moodCounts = allMoods.reduce(into: [:]) { counts, mood in counts[mood, default: 0] += 1 }
        // Get top 3 moods sorted by frequency
        self.topMoods = moodCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key.capitalized }
        print("🧠 InsightsViewModel: Top Moods - \(topMoods)")

        // Process Keywords
        let allKeywords = entries.compactMap { $0.keywords?.lowercased() }
                               .flatMap { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
                               .filter { !$0.isEmpty }
        
        let keywordCounts = allKeywords.reduce(into: [:]) { counts, keyword in counts[keyword, default: 0] += 1 }
        // Get top 5-7 common keywords sorted by frequency
        self.commonKeywords = keywordCounts.sorted { $0.value > $1.value }.prefix(7).map { $0.key }
        print("🧠 InsightsViewModel: Common Keywords - \(commonKeywords)")
    }
} 