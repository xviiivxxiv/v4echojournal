import SwiftUI
import AVFoundation // Keep for audio player
import CoreData // Import CoreData

struct HistoryView: View {
    // Use FetchRequest to get JournalEntryCD objects directly
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntryCD.createdAt, ascending: false)],
        animation: .default
    )
    private var journalEntries: FetchedResults<JournalEntryCD>

    // Computed property to group entries by day
    private var groupedEntries: [Date: [JournalEntryCD]] {
        Dictionary(grouping: journalEntries) { entry in
            // Normalize the date to the start of the day
            Calendar.current.startOfDay(for: entry.createdAt ?? Date())
        }
    }

    // Sorted array of dates (days) for section headers
    private var sortedDays: [Date] {
        groupedEntries.keys.sorted(by: >) // Sort days descending (most recent first)
    }
    
    // Date formatter for the section headers
    private var sectionDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy" // e.g., July 25, 2025
        // Consider using relative date formatting for recent dates if desired
        // formatter.dateStyle = .long
        // formatter.timeStyle = .none
        // formatter.doesRelativeDateFormatting = true
        return formatter
    }

    // State for potential deletion errors
    @State private var deletionError: String? = nil
    @State private var showDeletionErrorAlert = false

    // State to track scroll position for the button
    @State private var showScrollToTopButton = false
    private let topID = "top_of_list"

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.backgroundCream.ignoresSafeArea() // Set background color
            if journalEntries.isEmpty {
                emptyStateView
            } else {
                journalListView
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: JournalEntryCD.self) { entry in
            ConversationView(journalEntry: entry)
        }
        .alert("Deletion Failed", isPresented: $showDeletionErrorAlert, presenting: deletionError) { detail in
            Button("OK") { deletionError = nil }
        } message: { detail in
            Text(detail).font(.system(size: 14, weight: .regular, design: .default)) // SF Pro
        }
    }

    private var emptyStateView: some View {
            VStack {
                    Spacer()
                    Text("No journal entries yet.")
                .font(.system(size: 18, weight: .regular, design: .default)) // SF Pro
                        .foregroundColor(.secondaryTaupe)
                        .padding()
                    Spacer()
        }
    }

    private var journalListView: some View {
        ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 25) {
                                Color.clear.frame(height: 0).id(topID)
                    journalSectionList(proxy: proxy)
                            }
                            .padding(.horizontal)
                        }
            .overlay(alignment: .bottomTrailing) {
                             if showScrollToTopButton {
                                 Button {
                                     withAnimation(.smooth(duration: 0.5)) {
                            proxy.scrollTo(topID, anchor: .top)
                                     }
                                 } label: {
                                     Image(systemName: "arrow.up")
                            .font(Font.system(.title2, design: .rounded).weight(.semibold)) // SF Pro Rounded
                                         .foregroundColor(Color(hex: "#FDF9F3")) 
                                         .padding()
                                         .background(Color(hex: "#5C4433").opacity(0.85))
                                         .clipShape(Circle())
                                         .shadow(color: Color(hex: "#5C4433").opacity(0.3), radius: 10, x: 0, y: 5)
                                 }
                                 .padding()
                                 .transition(.scale.combined(with: .opacity))
                             }
                        }
                    }
                }

    private func journalSectionList(proxy: ScrollViewProxy) -> some View {
        ForEach(sortedDays, id: \.self) { day in
            // Date Header Section
            Text(day, formatter: sectionDateFormatter)
                .font(.system(size: 20, weight: .medium, design: .default)) // SF Pro
                .foregroundColor(Color(hex: "#5C4433"))
                .padding(.top)
                .background(GeometryReader { geometry -> Color in
                    let frame = geometry.frame(in: .global)
                    DispatchQueue.main.async {
                        self.showScrollToTopButton = frame.minY < 100
                    }
                    return Color.clear
                })
            // Entries for this day
            ForEach(groupedEntries[day] ?? []) { entry in
                NavigationLink(value: entry) {
                    JournalEntryCardView(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        offsets.map { journalEntries[$0] }.forEach { entry in
            viewContext.delete(entry)
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("❌ Unresolved error \(nsError), \(nsError.userInfo)")
            deletionError = "Failed to delete entry: \(error.localizedDescription)"
            showDeletionErrorAlert = true
        }
    }
}

// New Card View struct
struct JournalEntryCardView: View {
    let entry: JournalEntryCD

    // Date formatter for the time within the card
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a" // e.g., 5:30 PM
        return formatter
    }

    // Helper to get an emoji asset name for an emotion category (mirrors JournalEntryDetailView)
    private func emojiAssetNameForFeelingCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "great": return "emoji_great"
        case "good": return "emoji_good"
        case "fine": return "emoji_fine"
        case "bad": return "emoji_bad"
        case "terrible": return "emoji_terrible"
        default: return "questionmark.circle" // SF Symbol as a fallback
        }
    }

    // Determine overall feeling emoji asset name (mirrors JournalEntryDetailView)
    private var overallFeelingEmojiAssetName: String? {
        guard let feelingsSet = entry.identifiedFeelings as? NSOrderedSet,
              let feelings = feelingsSet.array as? [IdentifiedFeelingCD],
              let firstFeeling = feelings.first(where: { $0.category != nil && !$0.category!.isEmpty }) else {
            return nil
        }
        return emojiAssetNameForFeelingCategory(firstFeeling.category!)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) { // Changed alignment to center, adjusted spacing
            // Main content: Headline and Snippet
            VStack(alignment: .leading, spacing: 4) { // Reduced spacing
                if let headline = entry.headline, !headline.isEmpty {
                    Text(headline)
                        .font(.system(size: 17, weight: .semibold, design: .default)) // Prominent headline
                        .foregroundColor(Color(hex: "#5C4433"))
                        .lineLimit(2) // Allow headline to wrap
                } else { // Fallback if no headline
                    Text(entry.entryText ?? "Journal Entry")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundColor(Color(hex: "#5C4433"))
                        .lineLimit(1)
                }
                
                Text(entry.entryText ?? "No content")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(Color(hex: "#896A47")) // Softer color for snippet
                    .lineLimit(1) // Snippet line limit
            }
            .frame(maxWidth: .infinity, alignment: .leading) // Allow text to take available space

            // Overall Feeling Emoji on the right
            if let emojiName = overallFeelingEmojiAssetName {
                Image(emojiName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36) // Adjust size as needed
            } else if let mood = entry.mood, !mood.isEmpty { // Fallback to old mood emoji if no identified feelings yet
                Text(mood)
                    .font(.system(size: 28))
            }
            
            // Removed old time display and chevron from here, adjust as per full design
            // Image(systemName: "chevron.right")
            //     .foregroundColor(Color(hex: "#B7A99A").opacity(0.6))
            //     .font(Font.system(.footnote, design: .default).weight(.semibold))

        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)) // Adjusted padding
        .background(Color.white) // Changed background to white as per inspo card
        .cornerRadius(16) // Consistent corner radius
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2) // Softer shadow
    }

    // Helper functions for mood tag styling (customize colors) - NO LONGER USED HERE
    // private func moodBackgroundColor(mood: String) -> Color { ... }
    // private func moodTextColor(mood: String) -> Color { ... }
}

// Preview needs adjustment if HistoryViewModel or JournalEntryRow changed significantly
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview needs a NavigationStack to show the title and toolbar
        NavigationStack {
            HistoryView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}

