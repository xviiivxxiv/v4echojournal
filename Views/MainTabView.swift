import SwiftUI

struct MainTabView: View {
    // ViewModels that might be needed by HomeView or its children can be kept here
    // or passed down if HomeView initializes them directly.
    // For now, we keep these if HomeView or its sub-views (HistoryView, InsightsView)
    // rely on them being in the environment.
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var transcriptionVM = TranscriptionViewModel(transcriptionService: WhisperTranscriptionService.shared)
    @StateObject private var audioRecordingVM = AudioRecordingViewModel()

    var body: some View {
        // HomeView now manages its own navigation and tab bar display.
        // It contains a NavigationStack for its sub-views.
        HomeView()
            .environmentObject(settingsViewModel)
            .environmentObject(transcriptionVM)
            .environmentObject(audioRecordingVM)
            // Ensure managedObjectContext is also passed if HomeView or its children need it directly,
            // though typically it's accessed via @Environment within those views if fetched there.
            // Preview context is handled in HomeView_Previews, so this is for the main app flow.
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    // MainTabView now just shows HomeView which is self-contained for navigation
    MainTabView()
        .environment(\.managedObjectContext, context)
        // Environment objects for preview. Ensure these match what HomeView and its children expect.
        .environmentObject(SettingsViewModel())
        .environmentObject(TranscriptionViewModel(transcriptionService: WhisperTranscriptionService.shared))
        .environmentObject(AudioRecordingViewModel())
        // If ConversationViewModel is used by a view presented from HomeView (like ConversationView),
        // it might need to be set up differently or passed directly. For now, removed if not directly used by HomeView itself.
        // .environmentObject(ConversationViewModel(journalEntry: JournalEntryCD.preview(context: context), context: context))
}

// Helper for previewing JournalEntryCD if needed by ConversationViewModel
// extension JournalEntryCD {
//    static func preview(context: NSManagedObjectContext) -> JournalEntryCD {
//        let entry = JournalEntryCD(context: context)
//        entry.id = UUID()
//        entry.createdAt = Date()
//        entry.entryText = "Preview entry text for conversation."
//        entry.audioURL = URL(string: "file:///preview_audio.m4a")?.absoluteString
//        // ... any other required fields
//        return entry
//    }
// } 