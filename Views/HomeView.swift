import SwiftUI
import CoreData

struct HomeView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if audioRecorder.isRecording.value {
                    Label("Recording...", systemImage: "mic.fill")
                        .foregroundColor(.red)
                }

                Spacer()
                
                // Display Transcribed Text
                if !viewModel.transcribedText.isEmpty {
                    ScrollView {
                        Text(viewModel.transcribedText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 200) // Limit height
                } else if viewModel.isLoading && !viewModel.isRecording { // Show loading only during processing
                    ProgressView()
                        .scaleEffect(1.5)
                }
                
                Spacer()

                // Status Message
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                 // Error Message
                 if let errorMessage = viewModel.errorMessage {
                     Text("Error: \(errorMessage)")
                         .font(.caption)
                         .foregroundColor(.red)
                         .padding(.horizontal)
                         .multilineTextAlignment(.center)
                 }

                // Recording Button
                Button {
                    viewModel.toggleRecording()
                } label: {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(viewModel.isRecording ? .red : .blue)
                        // Add a subtle animation when recording
                        .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                        .animation(.spring(), value: viewModel.isRecording)
                }
                .padding(.bottom, 30)
                // Disable button briefly during processing if needed
                // .disabled(viewModel.isLoading && !viewModel.isRecording)
                
            }
            .padding()
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("History") {
                        HistoryView()
                    }
                }
            }
            .navigationDestination(item: $viewModel.newlySavedEntry) { entry in
                ConversationView(journalEntry: entry)
            }
            .alert("No Internet Connection", isPresented: $viewModel.showOfflineAlert) {
                Button("OK") {}
            } message: {
                Text("GPT follow-ups require Wi-Fi or Mobile Data.")
            }
            .onAppear {
                viewModel.newlySavedEntry = nil
                // Optional: Check auth status on appear if needed
                // viewModel.checkAuthentication()
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let dummyRecorder = AudioRecorder.shared
        HomeView(audioRecorder: dummyRecorder)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
