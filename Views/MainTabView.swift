import SwiftUI

struct MainTabView: View {
    // This view is now a pure container. All its necessary ViewModels
    // are passed down from the RootView via the environment.

    var body: some View {
        HomeView()
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    // The preview now needs to provide all the environment objects that HomeView and its children will use.
    MainTabView()
        .environment(\.managedObjectContext, context)
        .environmentObject(SettingsViewModel())
        .environmentObject(TranscriptionViewModel(transcriptionService: WhisperTranscriptionService.shared))
        .environmentObject(AudioRecordingViewModel())
        .environmentObject(HomeViewModel(transcriptionService: WhisperTranscriptionService.shared))
} 
        // If ConversationViewModel is used by a view presented from HomeView (like ConversationView),
        // it might need to be set up differently or passed directly. For now, removed if not directly used by HomeView itself.
        // .environmentObject(ConversationViewModel(journalEntry: JournalEntryCD.preview(context: context), context: context))

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