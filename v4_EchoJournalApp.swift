//
//  v4_EchoJournalApp.swift
//  v4 EchoJournal
//
//  Created by Papi on 21/04/2025.
//

import SwiftUI
import FirebaseCore

@main
struct v4_EchoJournalApp: App {
    // Connect the custom AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Inject the PersistenceController into the environment
    let persistenceController = PersistenceController.shared
    // Use the singleton instance, no need for @StateObject here
    let audioRecorder = AudioRecorder.shared

    init() {
        // Remove the incorrect StateObject initialization
        // _audioRecorder = StateObject(wrappedValue: AudioRecorder())
        
        print("🏁 App Initializing... Forcing Singleton inits.")
        // Explicitly access the singletons to trigger their initialization
        _ = GPTService.shared
        _ = WhisperTranscriptionService.shared
        _ = NetworkMonitor.shared
        
        // Firebase is now configured in the AppDelegate
        
        print("🏁 App Initialization Complete.")
    }

    var body: some Scene {
        WindowGroup {
            // Show RootView which will decide whether to show login or main app
            RootView()
                // Pass the necessary environment objects down
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
