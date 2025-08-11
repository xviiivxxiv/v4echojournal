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

    // Track selected entry for navigation (alternative to direct NavigationLink in ForEach if needed)
    // @State private var selectedEntryForNavigation: JournalEntryCD?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 1. Definitive, edge-to-edge background layer.
            Color(hex: "#5c4433").ignoresSafeArea()

            if journalEntries.isEmpty {
                emptyStateView
            } else {
                // 2. Use a simple ScrollView with no horizontal padding.
                ScrollViewReader { proxy in
                    ScrollView {
                        // The LazyVStack also has no horizontal padding, allowing its content to be controlled individually.
                        LazyVStack(alignment: .leading, spacing: 25) {
                            // Custom "Journal" title, styled like YouView's header
                            Text("Journal")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "#fdf9f3")) // Cream text for contrast
                                .frame(maxWidth: .infinity, alignment: .center) // Center align
                                .padding(.top, 15)
                                .padding(.bottom, 10) // Space between title and first date
                            
                            Color.clear.frame(height: 0).id(topID)

                            ForEach(sortedDays, id: \.self) { day in
                                // 3. Padding is applied directly to the content (the header Text).
                                Text(day, formatter: sectionDateFormatter)
                                    .font(.system(size: 20, weight: .medium, design: .default))
                                    .foregroundColor(Color(hex: "#FDF9F3"))
                                    .padding(.top)
                                    .padding(.horizontal, 16) // Explicit horizontal padding
                                    .background(GeometryReader { geometry -> Color in
                                        let frame = geometry.frame(in: .global)
                                        DispatchQueue.main.async {
                                            self.showScrollToTopButton = frame.minY < 100
                                        }
                                        return Color.clear
                                    })
                                
                                // Entries for this day
                                ForEach(groupedEntries[day] ?? []) { entry in
                                    // 3. Padding is applied directly to the content (the NavigationLink).
                                    NavigationLink(value: entry) {
                                        JournalEntryCardView(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 16) // Explicit horizontal padding
                                }
                            }
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if showScrollToTopButton {
                            Button {
                                withAnimation(.smooth(duration: 0.5)) {
                                    proxy.scrollTo(topID, anchor: .top)
                                }
                            } label: {
                                Image(systemName: "arrow.up")
                                    .font(Font.system(.title2, design: .rounded).weight(.semibold))
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: JournalEntryCD.self) { entry in
            // The destination was changed to JournalEntryDetailView in a previous step,
            // but the provided context shows ConversationView. Reverting to the correct one.
            JournalEntryDetailView(entry: entry)
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

    // Helper to sort photos by their 'timestamp' attribute
    private var sortedPhotos: [JournalPhoto] {
        guard let photosSet = entry.photos as? NSOrderedSet else { return [] }
        return (photosSet.array as? [JournalPhoto] ?? []).sorted {
            // Sort by timestamp, oldest first. Use distantPast as a fallback for nil timestamps.
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { // Main container for the card's content
            if !sortedPhotos.isEmpty {
                // MARK: - Layout WITH Photos
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) { // Photos touch
                        ForEach(Array(sortedPhotos.enumerated()), id: \.element.id) { index, photo in
                            if let imageData = photo.imageData, let uiImage = UIImage(data: imageData) {
                                let rotationAngle: Double = {
                                    switch index % 4 {
                                    case 1: return 3
                                    case 3: return -3
                                    default: return 0
                                    }
                                }()
                                
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 80) // Adjusted height
                                    .clipped()
                                    .cornerRadius(6)
                                    .rotationEffect(.degrees(rotationAngle))
                            }
                        }
                    }
                    .padding(.horizontal, 16) // Padding for the row of images within ScrollView
                }
                .frame(height: 80) // ScrollView height matches image height
                .padding(.top, 16) // Whitespace above the photo gallery
                .overlay(alignment: .topTrailing) { // Emoji positioned over the gallery
                    Group { // Use Group to apply padding once and handle conditional emoji
                        if let emojiName = overallFeelingEmojiAssetName {
                            Image(emojiName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                        } else if let mood = entry.mood, !mood.isEmpty { // Fallback for old mood
                            Text(mood)
                                .font(.system(size: 28)) // Match original size if it's text
                                .foregroundColor(Color(hex: "#FDF9F3")) // Cream text
                        }
                    }
                    // Padding for emoji within overlay, from edges of ScrollView
                    .padding(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 4))
                }

                // Text Content (Headline and Snippet) - Full Width below gallery
                VStack(alignment: .leading, spacing: 4) {
                    if let headline = entry.headline, !headline.isEmpty {
                        Text(headline) // Reverted from lowercased
                            .font(.system(size: 17, weight: .semibold, design: .default))
                            .foregroundColor(Color(hex: "#5c4433")) // Dark brown text
                            .lineLimit(2)
                    } else { // Fallback if no headline
                        Text(entry.entryText ?? "Journal Entry") // Reverted from lowercased
                            .font(.system(size: 17, weight: .semibold, design: .default))
                            .foregroundColor(Color(hex: "#5c4433")) // Dark brown text
                            .lineLimit(1)
                    }
                    
                    Text(entry.entryText ?? "No content") // Reverted from lowercased
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(Color(hex: "#5c4433").opacity(0.75)) // Dark brown text, slightly transparent
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading) // Ensure text takes full width
                .padding(.horizontal, 16) // Side padding for text
                .padding(.top, 16)       // Space between gallery and text
                .padding(.bottom, 16)    // Matching bottom padding for the card content
            } else {
                // MARK: - Layout WITHOUT Photos
                HStack(alignment: .center, spacing: 12) {
                    // Text content on the left
                    VStack(alignment: .leading, spacing: 4) {
                        if let headline = entry.headline, !headline.isEmpty {
                            Text(headline) // Reverted from lowercased
                                .font(.system(size: 17, weight: .semibold, design: .default))
                                .foregroundColor(Color(hex: "#5c4433")) // Dark brown text
                                .lineLimit(2)
                        } else { // Fallback if no headline
                            Text(entry.entryText ?? "Journal Entry") // Reverted from lowercased
                                .font(.system(size: 17, weight: .semibold, design: .default))
                                .foregroundColor(Color(hex: "#5c4433")) // Dark brown text
                                .lineLimit(1)
                        }
                        
                        Text(entry.entryText ?? "No content") // Reverted from lowercased
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(Color(hex: "#5c4433").opacity(0.75)) // Dark brown text, slightly transparent
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Emoji on the right
                    if let emojiName = overallFeelingEmojiAssetName {
                        Image(emojiName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    } else if let mood = entry.mood, !mood.isEmpty { // Fallback for old mood
                        Text(mood)
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "#5c4433")) // Dark brown text
                    }
                }
                // Consistent 16pt padding for the no-photo state
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }
        }
        .background(Color(hex: "#fdf9f3")) // Solid cream background
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
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

