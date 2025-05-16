//
//  v4_EchoJournalApp.swift
//  v4 EchoJournal
//
//  Created by Papi on 21/04/2025.
//

import SwiftUI

@main
struct v4_EchoJournalApp: App {
    // Inject the PersistenceController into the environment
    let persistenceController = PersistenceController.shared
    // Use the singleton instance, no need for @StateObject here
    let audioRecorder = AudioRecorder.shared
    @StateObject private var settingsViewModel = SettingsViewModel()

    init() {
        // Remove the incorrect StateObject initialization
        // _audioRecorder = StateObject(wrappedValue: AudioRecorder())
        
        print("🏁 App Initializing... Forcing Singleton inits.")
        // Explicitly access the singletons to trigger their initialization
        _ = GPTService.shared
        _ = WhisperTranscriptionService.shared
        _ = NetworkMonitor.shared
        print("🏁 App Initialization Complete.")
    }

    var body: some Scene {
        WindowGroup {
            // Show MainTabView as the root view after onboarding is implicitly handled
            MainTabView()
                // Pass the necessary environment objects down
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(settingsViewModel)
        }
    }
}
