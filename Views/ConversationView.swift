import SwiftUI
import CoreData

struct ConversationView: View {
    @StateObject private var viewModel: ConversationViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var temporaryAnswers: [UUID: String] = [:]

    init(journalEntry: JournalEntryCD) {
        _viewModel = StateObject(wrappedValue: ConversationViewModel(
            journalEntry: journalEntry,
            context: PersistenceController.shared.container.viewContext
        ))
    }

    var body: some View {
        List {
            originalEntrySection
            followUpQuestionsSection

            if viewModel.canAskMore {
                Section {
                    Button("Ask Another Question") {
                        viewModel.generateFollowUpQuestions()
                    }
                    .disabled(viewModel.isLoadingQuestions)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            if viewModel.isLoadingQuestions {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Generating Reflection...")
                        Spacer()
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Reflection")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reflection Error", isPresented: $viewModel.showErrorAlert, presenting: viewModel.errorMessage) { _ in
            Button("OK") { viewModel.errorMessage = nil }
        } message: { message in
            Text(message)
        }
        .onAppear {
            viewModel.loadFollowUps() // ✅ Ensure it's being called as a function
            if viewModel.followUps.isEmpty {
                viewModel.generateFollowUpQuestions()
            }
        }
        .onReceive(viewModel.$followUps) { updateTemporaryAnswers(from: $0) }
    }

    private var originalEntrySection: some View {
        Section(header: Text("Original Entry")) {
            Text(viewModel.journalEntry.entryText ?? "No transcript")
                .foregroundColor(.primary)
                .padding(.vertical, 5)
        }
    }

    private var followUpQuestionsSection: some View {
        Section(header: Text("Follow-up Reflection")) {
            if viewModel.followUps.isEmpty && !viewModel.isLoadingQuestions && !viewModel.canAskMore {
                Text("Tap 'Ask Another Question' to start reflecting, or no more questions available.")
                    .foregroundColor(.secondary)
            }

            ForEach(viewModel.followUps) { followUp in
                VStack(alignment: .leading, spacing: 8) {
                    Text(followUp.question ?? "Empty Question")
                        .font(.body)

                    TextField("Your thoughts...", text: answerBinding(for: followUp))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            viewModel.saveAnswer(for: followUp, answer: temporaryAnswers[followUp.id] ?? "")

                        }
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteFollowUp)
        }
    }

    // MARK: - Helpers

    private func answerBinding(for followUp: FollowUpCD) -> Binding<String> {
        let id = followUp.id
        return Binding<String>(
            get: { temporaryAnswers[id] ?? followUp.answer ?? "" },
            set: { temporaryAnswers[id] = $0 }
        )
    }

    private func updateTemporaryAnswers(from followUps: [FollowUpCD]) {
        var updated: [UUID: String] = [:]
        for followUp in followUps {
            let id = followUp.id
            updated[id] = temporaryAnswers[id] ?? followUp.answer ?? ""
        }
        temporaryAnswers = updated
    }

    private func deleteFollowUp(at offsets: IndexSet) {
        offsets.map { viewModel.followUps[$0] }.forEach(viewContext.delete)
        do {
            try viewContext.save()
        } catch {
            print("❌ Delete failed: \(error.localizedDescription)")
            viewModel.errorMessage = "Failed to delete follow-up: \(error.localizedDescription)"
            viewModel.showErrorAlert = true
            viewContext.rollback()
        }
    }
}

