import SwiftUI
import CoreData
import PhotosUI // Added for PhotosPicker

struct JournalEntryDetailView: View {
    @ObservedObject var entry: JournalEntryCD
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext // For saving photos

    // State for PhotosPicker
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    // Constants
    private let maxPhotoCount = 5
    private let photoThumbnailSize: CGSize = CGSize(width: 100, height: 133) // Aspect ratio 3:4
    private let largeAddPhotoBoxSize: CGSize = CGSize(width: 150, height: 200) // For empty state

    // State for error handling
    @State private var showPhotoErrorAlert = false
    @State private var photoErrorTitle = ""
    @State private var photoErrorMessage = ""
    
    // State for photo modal
    @State private var selectedPhotoForModal: JournalPhoto? = nil
    @State private var showPhotoModal = false

    // State for Edit Mode
    @State private var isInEditMode = false
    
    // State for Add Keyword Alert
    @State private var showAddKeywordAlert = false
    @State private var newKeywordText = ""

    // State for selecting overall feeling category
    @State private var showFeelingCategorySelector = false
    @State private var emojiButtonFrame: CGRect = .zero // For positioning the selector

    // Define brand colors for the gradient
    let topGradientColor = Color(hex: "5C4433")
    let bottomGradientColor = Color(hex: "FDF9F3")

    // Computed property for categorized emotions display
    private var categorizedFeelings: [String: [IdentifiedFeelingCD]] {
        guard let feelingsSet = entry.identifiedFeelings as? NSOrderedSet,
              let feelings = feelingsSet.array as? [IdentifiedFeelingCD] else {
            return [:]
        }
        return Dictionary(grouping: feelings, by: { $0.category ?? "Unknown" })
    }

    // Helper to get an emoji asset name for an emotion category
    private func emojiAssetNameForFeelingCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "great": return "emoji_great"
        case "good": return "emoji_good"
        case "fine": return "emoji_fine"
        case "bad": return "emoji_bad"
        case "terrible": return "emoji_terrible"
        default: return "questionmark.circle" // SF Symbol as a fallback for unknown category
        }
    }

    // Determine overall feeling emoji asset name
    private var overallFeelingEmojiAssetName: String? {
        if let userSelectedCategory = entry.userSelectedFeelingCategory, !userSelectedCategory.isEmpty {
            return emojiAssetNameForFeelingCategory(userSelectedCategory)
        }
        guard let feelingsSet = entry.identifiedFeelings as? NSOrderedSet,
              let feelings = feelingsSet.array as? [IdentifiedFeelingCD],
              let firstFeeling = feelings.first(where: { $0.category != nil && !$0.category!.isEmpty }) else {
            return nil
        }
        return emojiAssetNameForFeelingCategory(firstFeeling.category!)
    }
    
    private var overallFeelingCategoryName: String? {
        if let userSelectedCategory = entry.userSelectedFeelingCategory, !userSelectedCategory.isEmpty {
            return userSelectedCategory
        }
        guard let feelingsSet = entry.identifiedFeelings as? NSOrderedSet,
              let feelings = feelingsSet.array as? [IdentifiedFeelingCD],
              let firstFeeling = feelings.first(where: { $0.category != nil && !$0.category!.isEmpty }) else {
            return nil
        }
        return firstFeeling.category
    }

    // Date formatters
    private var headerDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd" // e.g., May 08
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a" // e.g., 09:07 PM
        return formatter
    }
    
    private var keywordsArray: [String] {
        guard let keywordsString = entry.keywords, !keywordsString.isEmpty else {
            return []
        }
        return keywordsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    }

    // Fallback title if keywords are not processed into a title
    private var entryTitle: String {
        if let headline = entry.headline, !headline.isEmpty {
            return headline // Prioritize headline
        }
        if !keywordsArray.isEmpty {
            return keywordsArray.joined(separator: ", ") // Fallback to keywords
        }
        // Fallback to the first part of the entry text
        let entryText = entry.entryText ?? "Journal Entry"
        return String(entryText.prefix(50)) + (entryText.count > 50 ? "..." : "")
    }

    // Computed property to get sorted messages
    private var messagesArray: [ConversationMessage] {
        guard let messages = entry.messages as? NSOrderedSet else {
            return []
        }
        return (messages.array as? [ConversationMessage] ?? []).sorted {
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast)
        }
    }

    // Computed property to get sorted photos
    private var photosArray: [JournalPhoto] {
        guard let photos = entry.photos as? NSOrderedSet else {
            return []
        }
        return (photos.array as? [JournalPhoto] ?? []).sorted {
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast)
        }
    }

    var body: some View {
        ZStack { // Root ZStack to allow overlay
            // Apply the gradient background to the ZStack
            LinearGradient(
                gradient: Gradient(colors: [topGradientColor, bottomGradientColor]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) { 
                    customNavigationBarArea
                    
                    // Interactive Emoji Row (Restored here)
                    HStack {
                        if let assetName = overallFeelingEmojiAssetName {
                            Button {
                                showFeelingCategorySelector.toggle()
                            } label: {
                                ZStack(alignment: .bottomTrailing) {
                                    Image(assetName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60) // Increased size of main interactive emoji
                                    Image(systemName: "chevron.down.circle.fill")
                                        .font(.system(size: 18)) // Slightly larger affordance to match
                                        .foregroundColor(.gray)
                                        .background(Circle().fill(Color.white).scaleEffect(1.2))
                                        .offset(x: 7, y: 7) // Adjusted offset slightly
                                }
                            }
                            .background(GeometryReader { geo in // Keep GeometryReader for positioning
                                Color.clear.preference(key: FramePreferenceKey.self, value: geo.frame(in: .global))
                            })
                        } else {
                            Spacer().frame(height: 60) // Restored placeholder height
                        }
                        Spacer() // Pushes emoji to the left
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 5) // Adjusted from previous
                    .padding(.bottom, 15) // Adjusted from previous

                    entryTitleArea
                    tagsArea
                    feelingsArea
                    photosArea
                    aiSummaryArea
                    conversationArea
                    Spacer() 
                }
            }
            .navigationBarHidden(true)
            .alert(photoErrorTitle, isPresented: $showPhotoErrorAlert, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text(photoErrorMessage)
            })
            .alert("Add Activity / Tag", isPresented: $showAddKeywordAlert, actions: {                
                TextField("Enter keyword", text: $newKeywordText).autocapitalization(.words)
                Button("Add") { if !newKeywordText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { addKeyword(newKeywordText.trimmingCharacters(in: .whitespacesAndNewlines)) } }
                Button("Cancel", role: .cancel) { }
            }, message: {
                 Text("Enter a new activity or tag for this journal entry.")
            })
            .sheet(isPresented: $showPhotoModal) { // Photo modal remains a sheet
                if let selectedPhoto = selectedPhotoForModal {
                    PhotoModalView(photo: selectedPhoto)
                }
            }
            .onPreferenceChange(FramePreferenceKey.self) { frame in
                self.emojiButtonFrame = frame
            }

            // Overlay for the custom feeling selector
            if showFeelingCategorySelector {
                // Tap-to-dismiss layer
                Color.black.opacity(0.001).ignoresSafeArea().onTapGesture { showFeelingCategorySelector = false }

                VStack(alignment: .center) { 
                    // This Spacer pushes the selector down.
                    // emojiButtonFrame.maxY is bottom of the tapped emoji. Add small spacing.
                    Spacer().frame(height: emojiButtonFrame.maxY + 120) // Adjusted to position popover top just below tapped emoji
                    
                    FeelingCategorySelectorView(
                        currentCategory: entry.userSelectedFeelingCategory ?? overallFeelingCategoryName ?? "Fine",
                        onSelectCategory: { selectedCategory in
                            updateUserSelectedFeelingCategory(selectedCategory)
                            showFeelingCategorySelector = false
                        }
                    )
                    .frame(width: UIScreen.main.bounds.width - 40) 
                    
                    Spacer() // Pushes the selector view up within this VStack
                }
                .ignoresSafeArea(.container, edges: .bottom)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: -20)), removal: .opacity.combined(with: .offset(y: -20))))
            }
        }
        // .animation(.easeInOut(duration: 0.25), value: showFeelingCategorySelector) // Animation on ZStack might be better
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showFeelingCategorySelector)
        // .padding(.bottom, 20) // Removed from ZStack
    }

    // MARK: - Subviews / ViewBuilder Functions

    @ViewBuilder
    private var customNavigationBarArea: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "FDF9F3"))
            }
            .padding(.leading, 16)

            Spacer()

            // VStack for Date and Time, centered
            if let createdAt = entry.createdAt {
                VStack(alignment: .center, spacing: 2) { // Spacing between date and time
                    Text(createdAt, formatter: headerDateFormatter)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "FDF9F3"))
                    Text(createdAt, formatter: timeFormatter)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "FDF9F3").opacity(0.8))
                }
            } else {
                VStack(alignment: .center, spacing: 2) {
                    Text("Date N/A")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "FDF9F3"))
                    Text("Time N/A")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "FDF9F3").opacity(0.8))
                }
            }
            
            Spacer()

            Button {
                isInEditMode.toggle()
            } label: {
                Text(isInEditMode ? "done" : "edit")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isInEditMode ? Color.red.opacity(0.8) : Color(hex: "FDF9F3"))
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 16) // Original top padding for nav bar elements
        // .padding(.bottom, 8) // Bottom padding might be handled by the new emoji row's top padding
        .frame(height: 48) // Approximate height from Figma - may need to increase for two lines
    }

    @ViewBuilder
    private var entryTitleArea: some View {
        HStack(alignment: .top) {
            Text(entryTitle.lowercased())
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "FDF9F3"))
                .lineLimit(nil)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var tagsArea: some View {
        if !keywordsArray.isEmpty || isInEditMode {
            VStack(alignment: .leading, spacing: 8) {
                Text("activities / tags")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "FDF9F3").opacity(0.85))
                    .padding(.leading, 16)
                    .padding(.bottom, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(keywordsArray.indices, id: \.self) { index in
                            let keyword = keywordsArray[index]
                            HStack(spacing: 4) {
                                Text(keyword)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "1C170D"))
                                
                                if isInEditMode {
                                    Button {
                                        deleteKeyword(keyword)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding(.horizontal, isInEditMode ? 10 : 16)
                            .padding(.vertical, 6)
                            .background(Color(hex: "F5F0E5"))
                            .cornerRadius(16)
                        }
                        
                        if isInEditMode {
                            Button {
                                newKeywordText = ""
                                showAddKeywordAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "A1824A"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color(hex: "E8E0D2"))
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 44)
            }
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var feelingsArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("feelings")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "FDF9F3").opacity(0.85))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            if let feelingsSet = entry.identifiedFeelings as? NSOrderedSet,
               let feelings = feelingsSet.array as? [IdentifiedFeelingCD], !feelings.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(feelings) { feeling in
                            HStack(spacing: 4) {
                                Text(feeling.name?.lowercased() ?? "unknown feeling")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "1C170D"))
                                
                                // Display category emoji instead of text
                                if let category = feeling.category, !category.isEmpty {
                                    Image(emojiAssetNameForFeelingCategory(category))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18) // Smaller emoji for inline display
                                } else {
                                    Image(systemName: "questionmark.circle") // Fallback if category is nil/empty
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                        .foregroundColor(.gray)
                                }
                                
                                if isInEditMode {
                                    // Button { /* TODO: Delete feeling */ } label: { Image(systemName: "minus.circle.fill") }
                                    // .foregroundColor(.red).font(.caption)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "F5F0E5"))
                            .cornerRadius(16)
                        }
                        // if isInEditMode { /* Add Feeling Button Here */ }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 44)
            } else {
                Text(isInEditMode ? "Add feelings in edit mode." : "No specific feelings identified for this entry.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                    .frame(height: 44, alignment: .leading)
            }
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var photosArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("photos to remember")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "FDF9F3").opacity(0.85))
                .padding(.horizontal, 16)
                .padding(.top, 16)

            if photosArray.isEmpty {
                addPhotoBoxView(isLarge: true)
                    .padding(.horizontal, 16)
                    .frame(height: largeAddPhotoBoxSize.height + 10)

            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photosArray) { photo in
                            if let imageData = photo.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: photoThumbnailSize.width, height: photoThumbnailSize.height)
                                    .cornerRadius(12)
                                    .clipped()
                                    .overlay(alignment: .topTrailing) {
                                        if isInEditMode {
                                            Button {
                                                deletePhoto(photo)
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.title2)
                                                    .foregroundColor(.red)
                                                    .background(Circle().fill(Color.white.opacity(0.7)))
                                                    .padding(6)
                                            }
                                        }
                                    }
                                    .onTapGesture {
                                        if !isInEditMode {
                                            selectedPhotoForModal = photo
                                            showPhotoModal = true
                                        }
                                    }
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: photoThumbnailSize.width, height: photoThumbnailSize.height)
                                    .cornerRadius(12)
                                    .overlay(Text("Error\nLoading").multilineTextAlignment(.center).font(.caption))
                            }
                        }
                        if photosArray.count < maxPhotoCount {
                            addPhotoBoxView(isLarge: false)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: photoThumbnailSize.height + 10)
            }
        }
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var aiSummaryArea: some View {
        if let summary = entry.aiSummary, !summary.isEmpty {
            let wordCount = entry.wordCountOfUserMessages

            VStack(alignment: .leading, spacing: 8) {
                Text("ENTRY SUMMARY (\(wordCount) WORDS)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "666666"))
                    .padding(.top, 16)

                Text(summary)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(hex: "333333"))
                    .lineSpacing(5)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "F7F7F7"))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var conversationArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("conversation")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "FDF9F3").opacity(0.85))
                .padding(.horizontal, 16)
                .padding(.top, 24)

            if !messagesArray.isEmpty {
                ForEach(messagesArray) { message in
                    messageBubble(message: message)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)
            } else if let entryText = entry.entryText, !entryText.isEmpty {
                Text("LEGACY ENTRY")
                    .font(.system(size: 14))
                    .foregroundColor(Color.gray)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 2)
                Text(entryText)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "1C170D"))
                    .lineSpacing(5)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
            } else {
                Text("No conversation text available.")
                    .font(.system(size: 16))
                    .foregroundColor(Color.gray)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
            }
        }
        .padding(.bottom, 20)
    }

    // Helper ViewBuilder for individual message bubbles
    @ViewBuilder
    private func messageBubble(message: ConversationMessage) -> some View {
        HStack {
            if message.sender == "user" { // Assuming "user" for user's messages
                Spacer()
            }
            Text(message.text ?? "Empty message")
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(message.sender == "user" ? Color(hex: "896a47") : Color(hex: "E0E0E0"))
                .foregroundColor(message.sender == "user" ? Color(hex: "FDF9F3") : Color(hex: "1C170D"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: UIScreen.main.bounds.width * 0.70, alignment: message.sender == "user" ? .trailing : .leading)
            
            if message.sender != "user" {
                Spacer()
            }
        }
        .padding(.vertical, 2) // Add a little vertical spacing between bubbles
    }

    // Helper ViewBuilder for the Add Photo Box
    @ViewBuilder
    private func addPhotoBoxView(isLarge: Bool) -> some View {
        let targetSize = isLarge ? largeAddPhotoBoxSize : photoThumbnailSize
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundColor(Color(hex: "A1824A").opacity(0.6))
                    .frame(width: targetSize.width, height: targetSize.height)
                
                Image(systemName: "plus")
                    .font(isLarge ? .system(size: 40) : .system(size: 24))
                    .foregroundColor(Color(hex: "A1824A").opacity(0.8))
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    savePhotoToCoreData(imageData: data)
                    selectedPhotoItem = nil
                } else {
                    if newItem != nil {
                        photoErrorTitle = "Error Loading Photo"
                        photoErrorMessage = "Could not load the selected photo. It might be in an unsupported format or corrupted. Please try a different photo."
                        showPhotoErrorAlert = true
                        print("❌ Error loading photo data from PhotosPickerItem")
                    }
                    selectedPhotoItem = nil
                }
            }
        }
    }
    
    // Helper for feeling placeholder - can be expanded later
    @ViewBuilder
    private func feelingPlaceholder(text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(Color(hex: "1C170D"))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "F5F0E5"))
            .cornerRadius(16)
    }

    // Helper function to save photo data
    private func savePhotoToCoreData(imageData: Data) {
        let storage = CoreDataStorage(context: viewContext)
        do {
            try storage.savePhoto(for: entry, imageData: imageData, caption: nil, timestamp: Date())
            print("📸 Photo saved and linked to entry.")
        } catch {
            photoErrorTitle = "Error Saving Photo"
            photoErrorMessage = "Could not save photo to your journal. Please try again. Details: \(error.localizedDescription)"
            showPhotoErrorAlert = true
            print("❌ Error saving photo to Core Data: \(error.localizedDescription)")
        }
    }
    
    // Placeholder for delete photo logic
    private func deletePhoto(_ photo: JournalPhoto) {
        print("Attempting to delete photo: \(photo.id?.uuidString ?? "N/A")")
        viewContext.delete(photo)
        do {
            try viewContext.save()
            print("🗑️ Photo deleted successfully.")
        } catch {
            photoErrorTitle = "Error Deleting Photo"
            photoErrorMessage = "Could not delete photo. Please try again. Details: \(error.localizedDescription)"
            showPhotoErrorAlert = true
            print("❌ Error deleting photo: \(error.localizedDescription)")
        }
    }

    // Helper to delete a keyword
    private func deleteKeyword(_ keywordToDelete: String) {
        var currentKeywords = keywordsArray
        currentKeywords.removeAll { $0.lowercased() == keywordToDelete.lowercased() }
        
        entry.keywords = currentKeywords.joined(separator: ", ")
        
        do {
            try viewContext.save()
            print("🗑️ Keyword '\(keywordToDelete)' deleted successfully.")
        } catch {
            photoErrorTitle = "Error Deleting Tag"
            photoErrorMessage = "Could not delete tag. Please try again. Details: \(error.localizedDescription)"
            showPhotoErrorAlert = true
            print("❌ Error deleting keyword: \(error.localizedDescription)")
        }
    }

    // Helper to add a new keyword
    private func addKeyword(_ newKeyword: String) {
        guard !newKeyword.isEmpty else { return }
        
        var currentKeywords = keywordsArray
        
        if currentKeywords.contains(where: { $0.lowercased() == newKeyword.lowercased() }) {
            photoErrorTitle = "Tag Exists"
            photoErrorMessage = "This tag already exists for this entry."
            showPhotoErrorAlert = true
            return
        }
        
        currentKeywords.append(newKeyword)
        entry.keywords = currentKeywords.joined(separator: ", ")
        
        do {
            try viewContext.save()
            print("✅ Keyword '\(newKeyword)' added successfully.")
        } catch {
            photoErrorTitle = "Error Adding Tag"
            photoErrorMessage = "Could not add tag. Please try again. Details: \(error.localizedDescription)"
            showPhotoErrorAlert = true
            print("❌ Error adding keyword: \(error.localizedDescription)")
        }
    }

    // Helper to update user-selected overall feeling category
    private func updateUserSelectedFeelingCategory(_ category: String) {
        entry.userSelectedFeelingCategory = category
        do {
            try viewContext.save()
            print("✅ User selected feeling category '\(category)' saved.")
        } catch {
            print("❌ Error saving user selected feeling category: \(error.localizedDescription)")
            // Optionally show an alert to the user
            photoErrorTitle = "Error Saving Feeling"
            photoErrorMessage = "Could not save your selected feeling. Details: \(error.localizedDescription)"
            showPhotoErrorAlert = true
        }
    }
}

// PreferenceKey to get frame of the emoji button
struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Feeling Category Selector View
struct FeelingCategorySelectorView: View {
    let currentCategory: String
    var onSelectCategory: (String) -> Void
    // @Environment(\.dismiss) private var dismiss // Dismiss is now handled by the parent view

    let categories = ["Terrible", "Bad", "Fine", "Good", "Great"]
    let primaryTextColor = Color(hex: "5C4433") // Define primary text color
    let secondaryTextColor = Color(hex: "5C4433").opacity(0.7) // Define secondary text color

    private func emojiAssetNameForFeelingCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "great": return "emoji_great"
        case "good": return "emoji_good"
        case "fine": return "emoji_fine"
        case "bad": return "emoji_bad"
        case "terrible": return "emoji_terrible"
        default: return "questionmark.circle"
        }
    }

    var body: some View {
        VStack(spacing: 15) { 
            Text("How are you feeling overall?")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(primaryTextColor) // Use defined primary color
                .padding(.top, 20)
                .padding(.bottom, 10)

            HStack(spacing: 10) { 
                ForEach(categories, id: \.self) { category in
                    Button {
                        onSelectCategory(category) // This will also trigger dismissal in parent
                    } label: {
                        VStack(spacing: 4) { 
                            Image(emojiAssetNameForFeelingCategory(category))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                            
                            Text(category)
                                .font(.system(size: 12, weight: currentCategory.lowercased() == category.lowercased() ? .bold : .regular))
                                .foregroundColor(currentCategory.lowercased() == category.lowercased() ? primaryTextColor : secondaryTextColor) // Use defined colors
                        }
                        .frame(width: 65) 
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(16)
    }
}

// MARK: - Photo Modal View
struct PhotoModalView: View {
    let photo: JournalPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                if let imageData = photo.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    VStack {
                        Text("Error loading image")
                        Button("Dismiss") { dismiss() }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Helper extension for Color hex
// Ensure this or a similar helper is available in your project
// extension Color {
//     init(hex: String) {
//         let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//         var int: UInt64 = 0
//         Scanner(string: hex).scanHexInt64(&int)
//         let a, r, g, b: UInt64
//         switch hex.count {
//         case 3: // RGB (12-bit)
//             (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//         case 6: // RGB (24-bit)
//             (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//         case 8: // ARGB (32-bit)
//             (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//         default:
//             (a, r, g, b) = (1, 1, 1, 0)
//         }
//         self.init(
//             .sRGB,
//             red: Double(r) / 255,
//             green: Double(g) / 255,
//             blue:  Double(b) / 255,
//             opacity: Double(a) / 255
//         )
//     }
// }

// MARK: - Preview
struct JournalEntryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleEntry: JournalEntryCD = {
            let entry = JournalEntryCD(context: context)
            entry.id = UUID()
            entry.createdAt = Date()
            entry.entryText = "Today, I tested a new journaling app. My initial expectation was met; I found the app's design clean and user-friendly, leading me to believe it will be useful for long-term use. I didn't specify what features contributed to this positive outlook, but the overall experience was smooth. The calendar view is particularly intuitive, and the streak tracking is a great motivator. I'm looking forward to exploring more of its features tomorrow."
            entry.mood = "😊"
            // Simulating keywords array as a comma-separated string
            let keywords = ["app testing", "swiftui", "journaling"]
            entry.keywords = keywords.joined(separator: ",")
            
            // <<< IMPORTANT: ADDED FOR AI SUMMARY PREVIEW >>>
            // Make sure JournalEntryCD has an optional String property `aiSummary`
            entry.aiSummary = "This is a sample AI summary of the journal entry, highlighting the user\\'s positive experience with a new journaling app. The design was found to be clean and user-friendly.\\n\\n• User tested a new journaling application.\\n• App design described as clean and user-friendly.\\n• Calendar view noted as intuitive.\\n• Streak tracking seen as a good motivator."
            
            return entry
        }()

        // To preview within a NavigationStack, as it's intended for navigation
        NavigationView { // Or NavigationStack for iOS 16+
            JournalEntryDetailView(entry: sampleEntry)
                // .environment(\.managedObjectContext, context) // Not strictly needed if entry is passed directly
        }
    }
} 