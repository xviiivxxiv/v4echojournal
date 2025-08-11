import SwiftUI
import CoreData // Added for NSManagedObjectContext

struct YouView: View {
    @Environment(\.managedObjectContext) private var viewContext // Core Data context
    @ObservedObject var homeViewModel: HomeViewModel // Added for HomeViewModel access
    private let streakManager = StreakManager() // Instantiate the manager
    private let calendarManager = JournalCalendarManager() // Instantiate calendar manager

    // FetchRequest to automatically update when CoreData changes
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntryCD.createdAt, ascending: false)],
        animation: .default // Optional: adds animation to list changes if entries were in a List
    ) private var allJournalEntries: FetchedResults<JournalEntryCD>

    // State variables for UI updates and animation
    @State private var currentStreak: Int = 0 // Will be updated from StreakManager
    @State private var nextMilestoneGoal: Int = 1 // Will be updated from StreakManager
    @State private var overallHighestStreak: Int = 0 // To track for logic
    
    @State private var animateStreakScale = false
    @State private var previousStreakValue: Int = 0

    // Calendar State
    @State private var displayedMonth: Date = Date() // Start with the current month
    @State private var journalEntriesMapInMonth: [Date: JournalEntryCD] = [:] // NEW

    // Stats Summary State
    @State private var totalUserWords: Int = 0 // NEW for words in journal
    @State private var literatureComparisonText: String = "" // Initialized empty, will be updated

    // Placeholder data (can be removed or updated as needed)
    @State private var longestStreak: Int = 0 // This might be redundant if overallHighestStreak is used
    @State private var weeksInJournal: Int = 0 // Placeholder, update if you have this logic
    @State private var totalEntries: Int = 0   // Placeholder, update if you have this logic

    var body: some View {
        ZStack { // Root ZStack of YouView
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    customHeaderForYouView
                    
                    progressSection
                    
                    entriesCalendarSection
                    
                    statsSummarySection
                    
                    Spacer() // Ensures content pushes to the top if not enough to fill screen
                }
                .padding()
            }
            .background(Color.backgroundCream.ignoresSafeArea()) // Ensure background matches app theme
        }
        .navigationBarHidden(true)
        .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: displayedMonth)
        .onAppear {
            // Initial data load
            processFetchedEntries(entries: Array(allJournalEntries))
        }
        .onChange(of: allJournalEntries.count) { newCount in // Monitor count for changes
            // The actual content of `allJournalEntries` is already updated by @FetchRequest.
            // We just need to re-process it.
            print("YouView: allJournalEntries count changed to \(newCount), processing...")
            processFetchedEntries(entries: Array(allJournalEntries))
        }
        .onChange(of: displayedMonth) { _ in 
            // When month changes, re-filter calendar days based on all entries
            updateCalendarDaysForDisplayedMonth(entries: Array(allJournalEntries))
        }
        // .navigationTitle("You") // This will be set by HomeView
    }

    // MARK: - Custom Header for YouView
    @ViewBuilder
    private var customHeaderForYouView: some View {
        HStack {
            Spacer() // Pushes "you" text and icon away from leading edge
            
            Text("you") 
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "5C4433"))
                .textCase(.lowercase)
            
            Spacer() // Allows "you" text to center, pushes icon to trailing

            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(hex: "5C4433")) 
            }
        }
        .padding(.horizontal) 
        .padding(.top, 15)    
        .frame(height: 44)    
    }

    private func processFetchedEntries(entries: [JournalEntryCD]) {
        // Update streak data
        let newCurrentStreak = streakManager.calculateCurrentStreak(from: entries)
        if newCurrentStreak > previousStreakValue {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { animateStreakScale = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { animateStreakScale = false }
            }
        }
        previousStreakValue = newCurrentStreak
        currentStreak = newCurrentStreak
        
        overallHighestStreak = streakManager.getOverallHighestStreak(from: entries)
        // Note: The logic to *update* JournalEntryCD.highestStreak when a new entry is saved
        // and currentStreak > overallHighestStreak should reside where new entries are created and saved.
        // This view is primarily for displaying the data.
        
        nextMilestoneGoal = streakManager.calculateNextMilestone(currentStreak: newCurrentStreak)

        let oldTotalUserWords = self.totalUserWords // Capture old value for comparison
        var calculatedTotalWords = 0
        for entry in entries {
            calculatedTotalWords += entry.wordCountOfUserMessages
        }
        self.totalUserWords = calculatedTotalWords
        
        // totalEntries can be directly derived from entries.count where needed
        // self.totalEntries = entries.count // If you still want a separate state var for it

        // Update calendar data for the currently displayed month
        updateCalendarDaysForDisplayedMonth(entries: entries)

        // Fetch literature comparison if word count is significant and has changed or not yet fetched
        if self.totalUserWords > 20 && (self.literatureComparisonText.isEmpty || self.totalUserWords != oldTotalUserWords) {
            Task {
                self.literatureComparisonText = "Comparing to great works..." // Loading state
                do {
                    let comparison = try await GPTService.shared.generateLiteratureComparison(wordCount: self.totalUserWords)
                    if !comparison.isEmpty {
                        self.literatureComparisonText = comparison
                    } else {
                        self.literatureComparisonText = "Your journal is growing! Keep it up."
                    }
                } catch {
                    print("❌ YouView: Failed to generate literature comparison: \(error.localizedDescription)")
                    self.literatureComparisonText = "Could not fetch literary comparison at this time."
                }
            }
        } else if self.totalUserWords <= 20 {
            self.literatureComparisonText = "Write a bit more to see how your journal compares to famous texts!"
        }
    }
    
    private func updateCalendarDaysForDisplayedMonth(entries: [JournalEntryCD]) {
        journalEntriesMapInMonth = calendarManager.getJournalEntriesMapForMonth(for: displayedMonth, fromAllEntries: entries, using: viewContext)
    }

    private func changeMonth(by amount: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: amount, to: displayedMonth) {
            displayedMonth = newMonth // This will trigger .onChange(of: displayedMonth)
        }
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Progress")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "2C1D14"))
                .textCase(.lowercase)
                .padding(.bottom, 5)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "E8DECF"), lineWidth: 1) // Figma border color
                    )

                VStack(spacing: 8) {
                    HStack {
                        Text("Current streak")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "9E9E9E")) // Light brown
                        Spacer()
                        Text("Next milestone")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "9E9E9E")) // Light brown
                    }

                    HStack {
                        Text("🔥 \(currentStreak) \(pluralizeDays(currentStreak))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "3D3D3D")) // Dark brown
                            .scaleEffect(animateStreakScale ? 1.15 : 1.0) 
                        Spacer()
                        Text(">")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "3D3D3D")) // Dark brown
                        Spacer()
                        Text("🏁 \(nextMilestoneGoal) \(pluralizeDays(nextMilestoneGoal))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "3D3D3D")) // Dark brown
                            // Apply transition for milestone changes
                            .transaction { transaction in
                                transaction.animation = .easeInOut(duration: 0.3)
                            }
                    }
        }
                .padding(24)
            }
            .fixedSize(horizontal: false, vertical: true)
             // Add an ID to ensure the view redraws properly when nextMilestoneGoal changes, aiding animation.
            .id("progressCard_\(currentStreak)_\(nextMilestoneGoal)")
        }
    }

    private func pluralizeDays(_ count: Int) -> String {
        return count == 1 ? "day" : "days"
    }

    // MARK: - Entries Calendar Section
    private var entriesCalendarSection: some View {
        VStack(alignment: .leading, spacing: 15) { // Outer VStack for the whole section
            Text("Entries Calendar")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "2C1D14"))
                .textCase(.lowercase)
            
            // New Inner VStack for the white card content
            VStack(spacing: 12) { // Adjusted spacing for items inside the card
                // Calendar Header: Month Navigation
                HStack {
                    Button { changeMonth(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "5C4433"))
                    }
                    Spacer()
                    Text(monthYearString(for: displayedMonth))
                        .font(.custom("PlusJakartaSans-Bold", size: 16))
                        .foregroundColor(Color(hex: "5C4433"))
                    Spacer()
                    Button { changeMonth(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "5C4433"))
                    }
                }
                .padding(.horizontal, 8) // Reduced horizontal padding slightly
                .padding(.top, 8) // Added top padding inside the card

                // Day of Week Headers
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                    ForEach(Array(dayOfWeekSymbols().enumerated()), id: \.offset) { index, symbol in
                        Text(symbol)
                            .font(.custom("PlusJakartaSans-Bold", size: 13))
                            .foregroundColor(Color(hex: "5C4433"))
                            .frame(maxWidth: .infinity)
                    }
                }
                // Removed vertical padding here, spacing on parent VStack handles it

                // Calendar Days Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                    ForEach(generateDaysInMonth(for: displayedMonth), id: \.id) { dayInfo in
                        if let date = dayInfo.date {
                            Button(action: {
                                homeViewModel.tappedDateForModal = date
                                homeViewModel.entryForTappedDate = journalEntriesMapInMonth[date]
                                homeViewModel.showDateInteractionModal = true
                                print("YouView: Tapped on date: \(date), Entry found: \(homeViewModel.entryForTappedDate != nil). Notifying HomeViewModel.")
                            }) {
                                ZStack {
                                    if dayInfo.isToday && journalEntriesMapInMonth[date]?.feelingEmojiAssetName == nil {
                                        Circle().stroke(Color(hex: "5C4433"), lineWidth: 1.5)
                                    }

                                    if let entry = journalEntriesMapInMonth[date], let emojiName = entry.feelingEmojiAssetName {
                                        Image(emojiName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 30, height: 30)
                                    } else {
                                        Text("\(dayInfo.day)")
                                            .font(.custom("PlusJakartaSans-Medium", size: 14))
                                            .foregroundColor(dayCellForegroundColor(date: date, isToday: dayInfo.isToday, hasEntry: journalEntriesMapInMonth[date] != nil))
                                    }
                                }
                                .frame(width: 36, height: 36)
                            }
                            .opacity(dayInfo.isWithinDisplayedMonth ? 1.0 : 0.0)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 36, height: 36)
                        }
                    }
                }
                // Removed .padding() from here as the parent VStack now has it
            }
            .padding() // Padding for the content inside the white card (e.g., 16 pts all around)
            .background(Color.white.opacity(0.9)) // Made background slightly more opaque
            .cornerRadius(16) // Increased corner radius
            .shadow(color: Color.black.opacity(0.07), radius: 7, x: 0, y: 3) // Slightly adjusted shadow
        }
    }

    // MARK: - Calendar Helper Struct and Functions
    private struct DayInfo: Hashable {
        let id = UUID() // Add unique ID for each DayInfo instance
        let day: Int
        let date: Date?
        let isToday: Bool
        let isWithinDisplayedMonth: Bool
    }

    private func generateDaysInMonth(for displayDate: Date) -> [DayInfo] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday is 2 (Sunday is 1)

        guard let monthInterval = calendar.dateInterval(of: .month, for: displayDate),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthInterval.start)),
              let rangeOfDaysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else {
            return []
        }

        var days: [DayInfo] = []
        let today = calendar.startOfDay(for: Date())
        let numDaysInMonth = rangeOfDaysInMonth.count
        
        // weekday: 1 for Sunday, 2 for Monday, ..., 7 for Saturday
        // If calendar.firstWeekday = 2, then Monday will be component 1 *if the month starts on Monday*.
        // We need the actual weekday component of the firstDayOfMonth based on standard numbering (Sun=1, Mon=2...)
        let firstDayActualWeekday = Calendar(identifier: .gregorian).component(.weekday, from: firstDayOfMonth) 

        // Calculate padding based on Monday as the visual start of the week
        // If firstDayActualWeekday is Sunday (1), padding is 6.
        // If firstDayActualWeekday is Monday (2), padding is 0.
        // If firstDayActualWeekday is Tuesday (3), padding is 1.
        let leadingPadding = (firstDayActualWeekday - calendar.firstWeekday + 7) % 7

        for _ in 0..<leadingPadding {
            days.append(DayInfo(day: 0, date: nil, isToday: false, isWithinDisplayedMonth: false))
        }

        for dayOfMonth in 1...numDaysInMonth {
            if let dateForDay = calendar.date(byAdding: .day, value: dayOfMonth - 1, to: firstDayOfMonth) {
                let isCurrentDay = calendar.isDate(dateForDay, inSameDayAs: today)
                days.append(DayInfo(day: dayOfMonth, date: calendar.startOfDay(for: dateForDay), isToday: isCurrentDay, isWithinDisplayedMonth: true))
            }
        }
        
        // Add trailing empty cells to fill the grid (optional, depends on desired layout)
        // let totalCells = ( (firstDayWeekday - 1) + numDaysInMonth )
        // let remainingCells = (7 - (totalCells % 7)) % 7
        // for _ in 0..<remainingCells {
        //     days.append(DayInfo(day: 0, date: nil, isToday: false, isWithinDisplayedMonth: false))
        // }

        return days
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func dayOfWeekSymbols() -> [String] {
        // Explicitly set to start with Monday
        return ["M", "T", "W", "T", "F", "S", "S"]
    }
    
    private func dayCellForegroundColor(date: Date, isToday: Bool, hasEntry: Bool) -> Color {
        if hasEntry && journalEntriesMapInMonth[date]?.feelingEmojiAssetName != nil {
             return .clear
        }
        if isToday {
            return Color(hex: "5C4433")
        }
        return Color(hex: "5C4433")
    }

    @ViewBuilder
    private func dayCellBackground(date: Date, isToday: Bool, hasEntry: Bool) -> some View {
        if hasEntry && journalEntriesMapInMonth[date]?.feelingEmojiAssetName == nil {
            Circle().fill(Color(hex: "5C4433"))
        } else if isToday && journalEntriesMapInMonth[date]?.feelingEmojiAssetName == nil {
            EmptyView()
        } else {
            EmptyView()
        }
    }

    // MARK: - Stats Summary Section
    private var statsSummarySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("your journal") // CHANGED title & styling
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "2C1D14"))
                .textCase(.lowercase)
            
            HStack(spacing: 15) {
                // UPDATED statsCard calls
                statsCard(iconName: "doc.text.fill", value: "\(totalUserWords)", label: "Words in journal")
                statsCard(iconName: "list.bullet.rectangle.portrait.fill", value: "\(allJournalEntries.count)", label: "Total Entries")
            }
            
            // Display GPT comparison text
            if !literatureComparisonText.isEmpty {
                Text(literatureComparisonText)
                    .font(.system(size: 14))
                    .italic()
                    .foregroundColor(Color(hex: "5C4433"))
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @ViewBuilder
    private func statsCard(iconName: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { // Align content to leading
            Image(systemName: iconName)
                .font(.system(size: 20)) // Icon size
                .foregroundColor(Color(hex: "5C4433")) // Icon color
                .padding(.bottom, 4)

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded)) // Larger, bolder value
                .foregroundColor(Color(hex: "2C1D14")) // Darker color for value
            
            Text(label)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(Color(hex: "5C4433").opacity(0.8)) // Softer color for label
        }
        .padding(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) // Adjusted padding
        .frame(maxWidth: .infinity, alignment: .leading) // Ensure content aligns leading
        .background(Color.white) // Changed from white.opacity(0.7)
        .cornerRadius(16) // Slightly larger corner radius
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3) // Adjusted shadow
    }
}

#Preview {
    NavigationView { // Wrap in NavigationView for preview if YouView might have nav elements
        YouView(homeViewModel: HomeViewModel(transcriptionService: WhisperTranscriptionService.shared))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 