//
//  v4_EchoJournalApp.swift
//  v4 EchoJournal
//
//  Created by Papi on 21/04/2025.
//

import SwiftUI

@main
struct v4_EchoJournalApp: App {
    let persistenceController = PersistenceController.shared
    let audioRecorder = AudioRecorder() // create the recorder instance

    var body: some Scene {
        WindowGroup {
            HomeView(audioRecorder: audioRecorder)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
