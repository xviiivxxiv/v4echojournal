import SwiftUI
import AVFoundation // Keep for audio player
import CoreData // Import CoreData

struct HistoryView: View {
    // Use FetchRequest to get JournalEntryCD objects directly
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntryCD.createdAt, ascending: false)],
        animation: .default
    )
    private var journalEntries: FetchedResults<JournalEntryCD>

    // State for potential deletion errors
    @State private var deletionError: String? = nil
    @State private var showDeletionErrorAlert = false

    var body: some View {
        // Remove the outer NavigationView, it's handled by the parent NavigationStack
        // NavigationView {
            VStack {
                if journalEntries.isEmpty {
                    Text("No journal entries yet.")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(journalEntries) { entry in
                            NavigationLink(value: entry) { // Navigate using the entry object itself
                                VStack(alignment: .leading) {
                                    Text(entry.entryText ?? "No text")
                                        .lineLimit(2)
                                    Text(entry.createdAt ?? Date(), style: .date) + Text(" ") + Text(entry.createdAt ?? Date(), style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            // Define navigation destination for JournalEntryCD within this view's scope
            .navigationDestination(for: JournalEntryCD.self) { entry in
                ConversationView(journalEntry: entry)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton() // Use standard EditButton for deletion
                }
            }
            .alert("Deletion Failed", isPresented: $showDeletionErrorAlert, presenting: deletionError) { detail in
                Button("OK") { deletionError = nil }
            } message: { detail in
                Text(detail)
            }
        // }
        // .navigationViewStyle(.stack) // Remove old style
    }

    private func deleteItems(at offsets: IndexSet) {
        offsets.map { journalEntries[$0] }.forEach { entry in
            viewContext.delete(entry)
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("❌ Unresolved error \(nsError), \(nsError.userInfo)")
            deletionError = "Failed to delete entry: \(error.localizedDescription)"
            showDeletionErrorAlert = true
            // Consider rolling back if save fails, though deletion might be tricky to undo
            // viewContext.rollback()
        }
    }
}

// Preview needs adjustment if HistoryViewModel or JournalEntryRow changed significantly
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview needs a NavigationStack to show the title and toolbar
        NavigationStack {
            HistoryView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}

