import SwiftUI

struct DateInteractionModalView: View {
    let selectedDate: Date
    let entry: JournalEntryCD? // Optional entry
    var onDismiss: (() -> Void)? = nil // Closure to be called to dismiss
    var onCreateEntryTapped: (() -> Void)? = nil // NEW: For specific create entry action
    var onViewEntryTapped: ((JournalEntryCD) -> Void)? = nil // NEW: For navigating to detail view
    // Environment dismiss is less relevant for custom presented views that don't use system presentation
    
    var body: some View {
        // Capsule removed
        
        if let existingEntry = entry {
            // Make the viewEntryContent tappable for navigation
            Button { // WRAP content in a Button for tap action
                onViewEntryTapped?(existingEntry)
            } label: {
                viewEntryContent(entry: existingEntry)
            }
            .buttonStyle(.plain) // Use plain button style to keep original appearance
        } else {
            createEntryPrompt()
        }
        // The .background(LightBlurView().ignoresSafeArea(.all)) was here, 
        // but for precise toast-style, the background might be better applied 
        // in YouView to the container of this view, along with frame and cornerRadius.
        // For now, let's assume this view itself doesn't apply the main blur background.
        // It will have its own content backgrounds (like the white card in inspo).
    }

    // MARK: - Helper functions for feeling emoji (moved here)
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

    private var overallFeelingEmojiAssetName: String? {
        guard let entry = self.entry, // Access via self.entry if needed, or ensure entry is passed if this becomes static
              let feelingsSet = entry.identifiedFeelings as? NSOrderedSet,
              let feelings = feelingsSet.array as? [IdentifiedFeelingCD],
              let firstFeeling = feelings.first(where: { $0.category != nil && !$0.category!.isEmpty }) else {
            return nil
        }
        return emojiAssetNameForFeelingCategory(firstFeeling.category!)
    }

    // MARK: - View Entry Content (Toast Style - matching inspiration)
    @ViewBuilder
    private func viewEntryContent(entry: JournalEntryCD) -> some View {
        // Helpers are now outside this function
        
        // Main content HStack
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Headline (or fallback to entry text prefix)
                Text(entry.headline?.isEmpty == false ? entry.headline! : (entry.entryText ?? "Journal Entry"))
                    .font(.system(size: 17, weight: .semibold)) // Prominent headline font
                    .foregroundColor(Color(hex: "#333333")) // Darker text for white background
                    .lineLimit(2) // Allow headline to wrap
                
                // Entry text snippet
                Text(entry.entryText ?? "No content available.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "#666666")) // Softer color for snippet
                    .lineLimit(2) // Limit snippet lines
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            // Overall Feeling Emoji on the right
            if let emojiName = overallFeelingEmojiAssetName {
                Image(emojiName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40) // Adjusted size
            } else if let mood = entry.mood, !mood.isEmpty { // Fallback to old mood emoji
                Text(mood)
                    .font(.system(size: 36)) // Keep large if it's the old mood string
            }
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)) // Adjusted padding
        .frame(maxWidth: .infinity) // Take full width
        // .frame(height: 100) // Remove fixed height, let content define it or use minHeight
        .background(Color.white)
        .cornerRadius(20) // Larger corner radius for card style
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4) // Softer shadow
    }

    // MARK: - Create Entry Prompt (Toast Style)
    @ViewBuilder
    private func createEntryPrompt() -> some View {
        VStack(spacing: 10) {
            Text("Create new entry for this day?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            Spacer(minLength: 10)

            Button {
                print("Create Entry button tapped inside modal for \(selectedDate)")
                onCreateEntryTapped?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Create Entry")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "896a47"))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white)
                .cornerRadius(25)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "b7a99a"))
        )
    }
}

// Preview needs adjustment for toast style
#if DEBUG
struct DateInteractionModalView_Previews: PreviewProvider {
    static var previews: some View {
        let previewContext = PersistenceController.preview.container.viewContext
        let mockEntry: JournalEntryCD = {
            let entry = JournalEntryCD(context: previewContext)
            entry.id = UUID()
            entry.createdAt = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            entry.entryText = "Preview: Today, I tested a new journaling app."
            entry.mood = "👍"
            entry.keywords = "preview,test"
            return entry
        }()

        VStack(spacing: 20) {
            Text("Date (from parent view) would appear here.") // Placeholder
            DateInteractionModalView(
                selectedDate: mockEntry.createdAt!,
                entry: mockEntry,
                onDismiss: { print("Preview dismiss action") },
                onCreateEntryTapped: { print("Preview create entry action") },
                onViewEntryTapped: { tappedEntry in print("Preview view entry tapped: \(tappedEntry.id?.uuidString ?? "N/A")") }
            )
            .frame(width: UIScreen.main.bounds.width * 0.9)

            Text("Date (from parent view) would appear here.") // Placeholder
            DateInteractionModalView(
                selectedDate: Date(),
                entry: nil,
                onDismiss: { print("Preview dismiss action") },
                onCreateEntryTapped: { print("Preview create entry action") }
            )
            .frame(width: UIScreen.main.bounds.width * 0.9)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
    }
}
#endif 