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

    init() {
        // Remove the incorrect StateObject initialization
        // _audioRecorder = StateObject(wrappedValue: AudioRecorder())
        
        print("🏁 App Initializing... Forcing GPTService init.")
        // Explicitly access the singleton to trigger its initialization
        _ = GPTService.shared
        // Access other singletons if needed early
        _ = NetworkMonitor.shared
        print("🏁 App Initialization Complete.")
    }

    var body: some Scene {
        WindowGroup {
            // Pass the shared instance to HomeView
            HomeView(audioRecorder: audioRecorder)
                // Pass the managed object context down the environment
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
