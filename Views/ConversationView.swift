import SwiftUI
import CoreData

struct ConversationView: View {
    @ObservedObject private var viewModel: ConversationViewModel
    @StateObject private var followUpLoopController: FollowUpLoopController
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    init(journalEntry: JournalEntryCD) {
        let initialViewModel = ConversationViewModel(
            journalEntry: journalEntry,
            context: PersistenceController.shared.container.viewContext
        )
        _viewModel = ObservedObject(wrappedValue: initialViewModel)

        _followUpLoopController = StateObject(wrappedValue: FollowUpLoopController(
            context: PersistenceController.shared.container.viewContext,
            gptService: GPTService.shared,
            audioRecorder: AudioRecorder.shared
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            originalEntrySection(entryText: viewModel.journalEntry.entryText ?? "No transcript")
                .padding()

            Divider()

            controllerStateSection(controller: followUpLoopController)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Reflection")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reflection Error", isPresented: Binding<Bool>(
            get: { followUpLoopController.currentState.isError },
            set: { _,_ in /* Cannot set error state directly */ }
        ), presenting: followUpLoopController.currentState.errorMessage) { _ in
            Button("OK") { /* Maybe add logic to reset state if needed */ }
        } message: { message in
            Text(message)
        }
        .onAppear {
            followUpLoopController.startLoop(for: viewModel.journalEntry)
            print("ConversationView.onAppear: Called followUpLoopController.startLoop")
        }
    }

    private func originalEntrySection(entryText: String) -> some View {
        VStack(alignment: .leading) {
            Text("Original Entry")
                .font(.headline)
                .foregroundColor(.secondary)
            ScrollView {
                Text(entryText)
                    .foregroundColor(.primary)
            }
            .frame(maxHeight: 150)
        }
    }

    @ViewBuilder
    private func controllerStateSection(controller: FollowUpLoopController) -> some View {
        VStack {
            switch controller.currentState {
            case .idle:
                Text("Starting reflection...")
                    .foregroundColor(.secondary)
            case .thinking:
                ProgressView("Thinking...")
            case .showingQuestion:
                VStack(spacing: 20) {
                    Text(controller.currentQuestion)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                    Button("Ready to Answer") {
                        controller.userReadyToAnswer()
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .listening:
                VStack(spacing: 20) {
                     Text("Listening...")
                        .font(.title3)
                     if controller.showMicButton {
                        if controller.isRecording {
                            Button { controller.stopRecordingAndProcess() } label: {
                                Label("Stop Recording", systemImage: "stop.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                             Button { controller.startRecording() } label: {
                                Label("Start Recording", systemImage: "mic.circle.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            case .processingAnswer:
                ProgressView("Processing your answer...")
            case .finished:
                Text("Reflection complete. You can close this screen.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            case .error(let message):
                Text("Error: \(message)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

extension FollowUpLoopController.LoopState {
    var isError: Bool {
        if case .error = self { return true } else { return false }
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message } else { return nil }
    }
}

