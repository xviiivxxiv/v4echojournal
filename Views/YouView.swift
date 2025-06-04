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
    @State private var journalEntryDaysInMonth: Set<Date> = []

    // Placeholder data (can be removed or updated as needed)
    @State private var longestStreak: Int = 0 // This might be redundant if overallHighestStreak is used
    @State private var weeksInJournal: Int = 0 // Placeholder, update if you have this logic
    @State private var totalEntries: Int = 0   // Placeholder, update if you have this logic
    @State private var quoteOfTheWeek: String = "The best way to predict the future is to create it."
    // Placeholder for calendar - will be a simple grid representation
    // Placeholder for mood data

    var body: some View {
        ZStack { // Root ZStack of YouView
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    // Title for the "You" screen - managed by HomeView's navigationTitle
                    
                    progressSection
                    
                    entriesCalendarSection
                    
                    statsSummarySection
                    
                    quoteOfTheWeekSection
                    
                    moodSection
                    
                    Spacer() // Ensures content pushes to the top if not enough to fill screen
                }
                .padding()
            }
            .background(Color.backgroundCream.ignoresSafeArea()) // Ensure background matches app theme
        }
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

        // Update calendar data for the currently displayed month
        updateCalendarDaysForDisplayedMonth(entries: entries)
    }
    
    private func updateCalendarDaysForDisplayedMonth(entries: [JournalEntryCD]) {
        journalEntryDaysInMonth = calendarManager.getJournalEntryDays(for: displayedMonth, fromAllEntries: entries, using: viewContext)
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
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.primaryEspresso)
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
        VStack(alignment: .leading, spacing: 15) {
            Text("Entries Calendar")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.primaryEspresso)
            
            // Calendar Header: Month Navigation
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "1C170D"))
                }
                Spacer()
                Text(monthYearString(for: displayedMonth))
                    .font(.custom("PlusJakartaSans-Bold", size: 16)) // Figma: Plus Jakarta Sans, 700, 16px
                    .foregroundColor(Color(hex: "1C170D")) // Figma: #1C170D
                Spacer()
                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "1C170D"))
                }
            }
            .padding(.horizontal, 4)

            // Day of Week Headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                // Use .enumerated() to provide unique IDs for day symbols
                ForEach(Array(dayOfWeekSymbols().enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.custom("PlusJakartaSans-Bold", size: 13))
                        .foregroundColor(Color(hex: "1C170D"))
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar Days Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                // Use DayInfo.id for unique identification
                ForEach(generateDaysInMonth(for: displayedMonth), id: \.id) { dayInfo in
                    if let date = dayInfo.date {
                        Button(action: {
                            // Update HomeViewModel's state for modal
                            homeViewModel.tappedDateForModal = date
                            homeViewModel.entryForTappedDate = allJournalEntries.first(where: { entry in
                                guard let entryCreatedAt = entry.createdAt else { return false }
                                return Calendar.current.isDate(entryCreatedAt, inSameDayAs: date)
                            })
                            homeViewModel.showDateInteractionModal = true
                            print("YouView: Tapped on date: \(date), Entry found: \(homeViewModel.entryForTappedDate != nil). Notifying HomeViewModel.")
                        }) {
                            Text("\(dayInfo.day)")
                                .font(.custom("PlusJakartaSans-Medium", size: 14)) // Figma: Plus Jakarta Sans, 500, 14px
                                .foregroundColor(dayCellForegroundColor(date: date, isToday: dayInfo.isToday, hasEntry: journalEntryDaysInMonth.contains(date)))
                                .frame(width: 36, height: 36) // Approximate size from Figma (48x48 cell, text needs to fit)
                                .background(dayCellBackground(date: date, isToday: dayInfo.isToday, hasEntry: journalEntryDaysInMonth.contains(date)))
                                .clipShape(Circle())
                        }
                        .opacity(dayInfo.isWithinDisplayedMonth ? 1.0 : 0.0) // Hide days not in current month if needed, or style differently
                    } else {
                        Text("") // Empty cell for days outside the month, to maintain grid structure
                            .frame(width: 36, height: 36)
                    }
                }
            }
            .padding()
        .background(Color.white.opacity(0.7)) // Similar to other sections, or use Figma if specified for calendar card
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
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
        if hasEntry {
            return Color.white // Figma: Text on green circle is white
        }
        if isToday {
            // If today is also an entry day, it will be white on green.
            // If today is NOT an entry day, but needs special styling:
            return Color(hex: "009963") // Example: Green text for today if not an entry day.
                                      // The provided screenshot has day 5 (today) as green circle with white text.
                                      // Other days are black text. Assuming this is for non-entry, non-today days.
        }
        return Color(hex: "1C170D") // Default day number color from Figma
    }

    @ViewBuilder
    private func dayCellBackground(date: Date, isToday: Bool, hasEntry: Bool) -> some View {
        if hasEntry {
            Circle().fill(Color(hex: "009963")) // Figma: Green circle for entry day
        } else if isToday {
            // If today is *not* an entry day, but should still be visually distinct (e.g., an outline)
             Circle().stroke(Color(hex: "009963"), lineWidth: 1.5) // Example: Green outline for today
        } else {
            EmptyView() // No special background for other days
        }
    }

    // MARK: - Stats Summary Section
    private var statsSummarySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Stats Summary")
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(Color.primaryEspresso)
            
            HStack(spacing: 15) {
                statsCard(value: "\(weeksInJournal) weeks", label: "In Journal")
                statsCard(value: "\(totalEntries) entries", label: "Total Entries")
            }
        }
    }
    
    @ViewBuilder
    private func statsCard(value: String, label: String) -> some View {
        VStack {
            Text(value)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(Color.primaryEspresso)
            Text(label)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(Color.secondaryTaupe)
        }
        .padding(EdgeInsets(top: 15, leading: 10, bottom: 15, trailing: 10))
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.7))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Quote of the Week Section
    private var quoteOfTheWeekSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quote of the Week")
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(Color.primaryEspresso)
            
            VStack {
                Text("“\(quoteOfTheWeek)”")
                    .font(.system(size: 16, design: .default).italic())
                    .foregroundColor(Color.white)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("Refresh Quote") {
                    let quotes = ["Quote 1", "Quote 2", "Quote 3"]
                    quoteOfTheWeek = quotes.randomElement() ?? "Stay positive!"
                    print("Refresh quote tapped")
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.8))
                .padding(.top, 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                // Placeholder background image - replace with actual image
                Image(systemName: "photo.fill") // Placeholder system image
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.4)) // Dark overlay for text legibility
            )
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        }
    }

    // MARK: - Mood Section
    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Mood Insights")
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(Color.primaryEspresso)

            // Mood Distribution (Placeholder Bar Graph)
            VStack(alignment: .leading, spacing: 5) {
                Text("Mood Distribution")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundColor(Color.primaryEspresso)
                HStack(alignment: .bottom, spacing: 8) {
                    bar(value: 0.7, color: .green, label: "Happy")
                    bar(value: 0.4, color: .blue, label: "Sad")
                    bar(value: 0.9, color: .orange, label: "Excited")
                    bar(value: 0.5, color: .purple, label: "Calm")
                    bar(value: 0.3, color: .gray, label: "Tired")
                }
                .frame(height: 150)
                .padding()
                .background(Color.white.opacity(0.7))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }

            // Mood Flow (Placeholder Line Graph)
            VStack(alignment: .leading, spacing: 5) {
                Text("Mood Flow Over Time")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundColor(Color.primaryEspresso)
                ZStack {
                    Image(systemName: "chart.xyaxis.line") // Placeholder
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.secondaryTaupe.opacity(0.5))
                    Text("Line graph placeholder")
                        .font(.caption)
                        .foregroundColor(Color.secondaryTaupe)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.7))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
    }

    // Helper for bar graph
    @ViewBuilder
    private func bar(value: CGFloat, color: Color, label: String) -> some View {
        VStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(color.opacity(0.7))
                .frame(height: value * 100) // Max height for bar is 100
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Color.secondaryTaupe)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView { // Wrap in NavigationView for preview if YouView might have nav elements
        YouView(homeViewModel: HomeViewModel(transcriptionService: WhisperTranscriptionService.shared))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 