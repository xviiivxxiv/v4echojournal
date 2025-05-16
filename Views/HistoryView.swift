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

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
             // Time Display (Instead of Date, as date is now in the header)
             Text(entry.createdAt ?? Date(), formatter: timeFormatter)
                 // Apply brand body font (adjust size/weight)
                 // .font(.custom("Very Vogue", size: 14).weight(.medium)) // Placeholder
                 .font(.system(size: 14, weight: .medium, design: .default)) // SF Pro
                 .foregroundColor(Color(hex: "#896A47")) // Accent color
                 .frame(width: 70, alignment: .leading) // Adjust width if needed

             // Snippet and Mood Display
             VStack(alignment: .leading, spacing: 6) { // Increased spacing
                  Text(entry.entryText ?? "No content")
                     // Apply brand body font
                     // .font(.custom("Very Vogue", size: 16)) // Placeholder
                     .font(.system(size: 16, weight: .regular, design: .default)) // SF Pro
                     .foregroundColor(Color(hex: "#5C4433")) // Main text color
                     .lineLimit(2) // Updated line limit
                     .frame(maxWidth: .infinity, alignment: .leading) // Take remaining space

                  // Mood Tag (Placeholder - styling and data needed)
                  if let mood = entry.mood, !mood.isEmpty {
                      Text(mood.capitalized)
                          // Apply brand body font
                          // .font(.custom("Very Vogue", size: 12)) // Placeholder
                          .font(.system(size: 12, weight: .medium, design: .rounded)) // SF Pro Rounded
                          .padding(.horizontal, 10)
                          .padding(.vertical, 4)
                          .foregroundColor(moodTextColor(mood: mood)) // Dynamic text color
                          .background(moodBackgroundColor(mood: mood)) // Dynamic background color
                          .clipShape(Capsule())
                  }
         }

              // Add subtle arrow indicator for navigation
              Image(systemName: "chevron.right")
                  .foregroundColor(Color(hex: "#B7A99A").opacity(0.6)) // Softer accent color
                  .font(Font.system(.footnote, design: .default).weight(.semibold)) // Corrected SF Pro usage
                  .padding(.leading, 5)

         }
         .padding()
         // Use a lighter card background or just rely on main background
         .background(Color.white.opacity(0.5)) // Subtle card background against #FDF9F3
         .cornerRadius(12) // Slightly smaller corner radius
         .shadow(color: Color(hex: "#5C4433").opacity(0.08), radius: 8, x: 0, y: 4) // Soft shadow using brand color
    }

    // Helper functions for mood tag styling (customize colors)
    private func moodBackgroundColor(mood: String) -> Color {
        switch mood.lowercased() {
            case "anxious", "stressed", "overwhelmed", "angry": return Color.red.opacity(0.15)
            case "sad", "lonely", "down": return Color.blue.opacity(0.15)
            case "happy", "excited", "grateful", "joyful": return Color.green.opacity(0.15)
            case "calm", "relaxed", "peaceful": return Color.teal.opacity(0.15)
            case "tired", "exhausted": return Color.gray.opacity(0.15)
            default: return Color(hex: "#B7A99A").opacity(0.2) // Default neutral
        }
    }

    private func moodTextColor(mood: String) -> Color {
         switch mood.lowercased() {
             case "anxious", "stressed", "overwhelmed", "angry": return Color.red.opacity(0.9)
             case "sad", "lonely", "down": return Color.blue.opacity(0.9)
             case "happy", "excited", "grateful", "joyful": return Color.green.opacity(0.9)
             case "calm", "relaxed", "peaceful": return Color.teal.opacity(0.9)
             case "tired", "exhausted": return Color.gray.opacity(0.9)
             default: return Color(hex: "#5C4433").opacity(0.8) // Default text color
         }
    }
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

