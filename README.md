# EchoJournal v4

EchoJournal is a SwiftUI-based iOS app for voice journaling. It allows users to record audio, transcribe it using OpenAI's Whisper API, and engage in reflective follow-up conversations powered by GPT-4.

## Features

-   **Voice Recording:** Simple tap-to-record interface using AVFoundation.
-   **Audio Transcription:** Accurate transcription via OpenAI Whisper API.
-   **Reflective Follow-ups:** Engage in a dynamic conversation with GPT-4 based on your journal entry.
-   **History:** Browse and revisit past journal entries and reflections.
-   **Core Data Storage:** Securely stores journal entries and follow-ups locally.
-   **CloudKit Sync (Optional):** Potential for syncing across devices (check PersistenceController setup).
-   **Offline Handling:** Gracefully handles offline scenarios for API calls.

## Tech Stack

-   SwiftUI
-   Combine
-   Core Data
-   CloudKit (via NSPersistentCloudKitContainer)
-   AVFoundation
-   OpenAI API (Whisper & GPT-4)

## Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/xviiivxxiv/v4echojournal.git
    cd v4echojournal
    ```
2.  **API Key:**
    -   Obtain an API key from [OpenAI](https://platform.openai.com/account/api-keys).
    -   Open the Xcode project (`v4 EchoJournal.xcodeproj`).
    -   Go to the project settings -> `Info` tab for the `v4 EchoJournal` target.
    -   Add a new row with the key `OPENAI_API_KEY` (Type: String) and paste your API key as the value. **Do not commit your API key directly to the repository.**
3.  **Build and Run:** Select a target device or simulator and run the app from Xcode.

## Project Structure (Key Components)

-   `Views/`: Contains SwiftUI views (`HomeView`, `HistoryView`, `ConversationView`).
-   `ViewModels/`: Contains ObservableObjects managing state and logic for views (`HomeViewModel`, `ConversationViewModel`).
-   `Services/`: Houses services like `AudioRecorder`, `WhisperTranscriptionService`.
-   `CloudSync/`: Includes `PersistenceController` (Core Data + CloudKit setup) and `CoreDataStorage`.
-   `Models/`: Data structures, including `OpenAIModels` for API responses.
-   `Utils/`: Utility classes like `NetworkMonitor`.
-   `Resources/`: Assets, including the Core Data model (`.xcdatamodeld`).

## Contributing

Contributions are welcome! Please follow standard Git workflow (fork, branch, pull request). 