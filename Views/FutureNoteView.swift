import SwiftUI
import CoreData

struct FutureNoteView: View {
    // Inject TranscriptionViewModel from environment
    @EnvironmentObject var transcriptionViewModel: TranscriptionViewModel
    @EnvironmentObject var audioRecorder: AudioRecordingViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    // State variables
    @State private var showSaveConfirmation = false
    @State private var isProcessing = false
    @State private var currentRecordingID: UUID? = nil
    @State private var selectedDeliveryDate = Date()
    // Timer state
    @State private var recordingTimer: Timer? = nil
    @State private var elapsedTime: TimeInterval = 0.0

    var body: some View {
        ZStack {
            // Main background color
            Color(hex: "#FDF9F3").ignoresSafeArea()
            
            VStack {
                Spacer()
                if audioRecorder.isRecording {
                    Text(formatTimeInterval(elapsedTime))
                        .foregroundColor(Color(hex: "#896A47"))
                        .padding(.bottom, 5)
                }
                Text(audioRecorder.isRecording ? "Recording note..." : isProcessing ? "Processing note..." : "Leave a note for Future You")
                    // .font(.custom("Genty-Regular", size: 24))
                    .foregroundColor(Color(hex: "#5C4433")) 
                    .padding(.bottom, audioRecorder.isRecording ? 25 : 40)

                Button {
                    handleMicButtonTap()
                } label: {
                    if isProcessing {
                        ProgressView()
                           .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FDF9F3")))
                           .frame(width: 60, height: 60) // Match mic size
                           .padding(40)
                           .background(Color(hex: "#896A47")) // Different background while processing
                           .clipShape(Circle())
                           .shadow(radius: 10)
                    } else {
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "#FDF9F3"))
                            .padding(40)
                            .background(audioRecorder.isRecording ? Color.red.opacity(0.7) : Color(hex: "#5C4433"))
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    }
                }
                .disabled(isProcessing) // Disable button while processing
                
                Spacer()
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Future Me")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Note Saved", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your note has been saved for Future You!")
        }
        // Handle potential errors from view models if necessary
        // .alert("Error", isPresented: $audioViewModel.showError) { ... }
        // .alert("Error", isPresented: $transcriptionViewModel.showError) { ... }
        // --- Add onChange to manage timer --- 
        .onChange(of: audioRecorder.isRecording) { _, isNowRecording in
            if isNowRecording {
                startTimer()
            } else {
                stopTimer()
                // Optionally reset elapsedTime = 0 here if preferred
            }
        }
    }

    private func handleMicButtonTap() {
        if audioRecorder.isRecording {
            isProcessing = true
            Task {
                await audioRecorder.stopRecording()
                try? await Task.sleep(nanoseconds: 300_000_000) 
                await processRecording()
                isProcessing = false
                currentRecordingID = nil 
            }
        } else {
            let newID = UUID()
            currentRecordingID = newID
            Task {
                _ = await audioRecorder.startRecording(fileNameBase: newID.uuidString)
            }
        }
    }

    private func processRecording() async {
        guard let audioURL = audioRecorder.audioFileURL else {
            print("❌ FutureNoteView: Audio file URL missing from AudioRecorder.")
            isProcessing = false 
            return
        }
        guard let noteID = currentRecordingID else {
            print("❌ FutureNoteView: Recording ID missing during processing.")
            isProcessing = false
            return
        }

        print("FutureNoteView: Processing recording \(noteID) at \(audioURL.path)")

        guard let audioData = try? Data(contentsOf: audioURL) else {
            print("❌ FutureNoteView: Failed to read audio data from \(audioURL.path)")
            isProcessing = false
            return
        }

        do {
            // Call the ViewModel's transcribe method with .ramble mode
            let transcriptionText = try await transcriptionViewModel.transcribe(fileURL: audioURL, mode: .ramble)
            print("FutureNoteView: Transcription successful for \(noteID).")
            saveFutureNote(id: noteID, message: transcriptionText, audioURL: audioURL)
            showSaveConfirmation = true 
        } catch {
            print("❌ FutureNoteView: Transcription failed for \(noteID): \(error)")
        }
    }

    private func saveFutureNote(id: UUID, message: String, audioURL: URL) {
        let newFutureNote = FutureEntryCD(context: viewContext)
        newFutureNote.id = id
        newFutureNote.message = message
        let relativePath = "FutureNotesAudio/\(id.uuidString).m4a"
        newFutureNote.audioURL = relativePath
        newFutureNote.createdAt = Date()
        newFutureNote.deliveryDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())
        
        print("💾 Saving Future Note: ID \(id), Relative Path \(relativePath)")

        do {
            try viewContext.save()
            print("✅ Future Note saved successfully.")
        } catch {
            let nsError = error as NSError
            print("❌ Error saving Future Note: \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // --- Timer Management --- 
    private func startTimer() {
        // Invalidate existing timer if any
        stopTimer()
        // Reset elapsed time
        elapsedTime = 0.0
        // Start a new timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1.0
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

#Preview {
    NavigationView {
        FutureNoteView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(SettingsViewModel())
            .environmentObject(AudioRecordingViewModel())
            .environmentObject(TranscriptionViewModel(transcriptionService: WhisperTranscriptionService.shared))
    }
} 