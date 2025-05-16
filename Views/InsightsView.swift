import SwiftUI
import CoreData

// Define identifiable structs for moods and keywords
struct MoodItem: Identifiable {
    let id = UUID()
    let mood: String
}

struct KeywordItem: Identifiable {
    let id = UUID()
    let keyword: String
}

struct InsightsView: View {
    // Inject the managed object context
    @Environment(\.managedObjectContext) private var viewContext
    
    // StateObject to hold the ViewModel instance
    @StateObject private var viewModel: InsightsViewModel

    // Initializer to inject the context into the ViewModel
    init() {
        // Initialize the StateObject here, passing the context
        // This ensures it gets the context available in this View's environment
        // Note: This approach requires the context to be available when InsightsView is initialized.
        // Alternatively, pass the context explicitly if needed.
        _viewModel = StateObject(wrappedValue: InsightsViewModel(context: PersistenceController.shared.container.viewContext)) 
        // TODO: Ensure PersistenceController.shared.container.viewContext is the correct way to access your context here.
        // If viewContext environment variable is already populated when init runs, you could use that, but it's often safer this way.
    }
    
    // Define a simple flow layout for keywords
    let keywordLayout = [ GridItem(.adaptive(minimum: 100)) ]

    var body: some View {
        ZStack {
            // Use brand background color
            Color(hex: "#FDF9F3").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    
                     if viewModel.isLoading {
                         ProgressView("Loading Insights...")
                             .progressViewStyle(CircularProgressViewStyle())
                             .frame(maxWidth: .infinity, alignment: .center)
                     } else {
                         // Common Moods Section (Replaces Word Cloud)
                         Text("Common Moods")
                             .font(.system(size: 24, weight: .medium, design: .default)) // SF Pro
                             .foregroundColor(Color(hex: "#5C4433"))
                             .padding(.bottom, 5)

                         if !viewModel.topMoods.isEmpty {
                             // Display moods as simple text for now, styled like a mood ring
                             HStack(spacing: 15) {
                                 ForEach(viewModel.topMoods.map { MoodItem(mood: $0) }) { item in
                                     Text(item.mood)
                                         // Apply brand body font
                                         // .font(.custom("Very Vogue", size: 18))
                                         .font(.system(size: 18, weight: .medium, design: .rounded)) // SF Pro Rounded
                                         .foregroundColor(moodTextColor(mood: item.mood))
                                         .padding(.vertical, 8)
                                         .padding(.horizontal, 16)
                                         .background(moodBackgroundColor(mood: item.mood).opacity(0.7))
                                         .clipShape(Capsule())
                                 }
                                 Spacer() // Push moods to the left
                             }
                             .padding(.vertical, 10)
                         } else {
                             Text("Journal more to see your common moods.")
                                 // .font(.custom("Very Vogue", size: 16))
                                 .font(.system(size: 16, weight: .regular, design: .default)) // SF Pro (Added for consistency if uncommented)
                                 .foregroundColor(Color(hex: "#896A47"))
                         }

                         Divider().padding(.vertical, 15)
                         
                         // Common Keywords Section
                         Text("Common Themes")
                             .font(.system(size: 24, weight: .medium, design: .default)) // SF Pro
                             .foregroundColor(Color(hex: "#5C4433"))
                             .padding(.bottom, 10)
                             
                         if !viewModel.commonKeywords.isEmpty {
                            // Display keywords using a Flow Layout (adaptable grid)
                            LazyVGrid(columns: keywordLayout, spacing: 15) {
                                ForEach(viewModel.commonKeywords.map { KeywordItem(keyword: $0) }) { item in
                                     Text(item.keyword)
                                        // Apply brand body font
                                        // .font(.custom("Very Vogue", size: 16))
                                        .font(.system(size: 16, weight: .regular, design: .rounded)) // SF Pro Rounded
                                        .foregroundColor(Color(hex: "#5C4433").opacity(0.9))
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color(hex: "#B7A99A").opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                         } else {
                             Text("No common themes identified yet. Add keywords to your entries.")
                                // .font(.custom("Very Vogue", size: 16))
                                .font(.system(size: 16, weight: .regular, design: .default)) // SF Pro (Added for consistency if uncommented)
                                .foregroundColor(Color(hex: "#896A47"))
                         }
                         
                         Divider().padding(.vertical, 15)
                         
                         // Reflection Summary Section
                         Text("Reflection Summary")
                              .font(.system(size: 24, weight: .medium, design: .default)) // SF Pro
                              .foregroundColor(Color(hex: "#5C4433"))
                              .padding(.bottom, 10)
                         
                         Text(viewModel.reflectionSummary)
                              // Apply brand body font
                              // .font(.custom("Very Vogue", size: 17))
                              .font(.system(size: 17, weight: .regular, design: .default)) // SF Pro
                              .foregroundColor(Color(hex: "#5C4433"))
                              .lineSpacing(5)
                              .frame(maxWidth: .infinity, alignment: .leading)

                         // Optional: Affirmations or Weekly Count
                         // Text("Weekly Entries: \(viewModel.weeklyEntryCount)")
                         //     .font(.system(.caption, design: .default)) // SF Pro
                         //     .foregroundColor(.secondary)
                         //     .padding(.top)
                     }
                    
                    Spacer() // Push content up
                }
                .padding()
            }
            .refreshable { // Allow pull-to-refresh
                viewModel.fetchAndProcessInsights()
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline) // Use inline to match other tabs
        // No toolbar items needed for now
        // .toolbar { ... }
    }
    
    // Re-use mood styling functions (or move to a shared location)
    private func moodBackgroundColor(mood: String) -> Color {
         switch mood.lowercased() {
             case "anxious", "stressed", "overwhelmed", "angry": return Color.red.opacity(0.15)
             case "sad", "lonely", "down": return Color.blue.opacity(0.15)
             case "happy", "excited", "grateful", "joyful": return Color.green.opacity(0.15)
             case "calm", "relaxed", "peaceful": return Color.teal.opacity(0.15)
             case "tired", "exhausted": return Color.gray.opacity(0.15)
             default: return Color(hex: "#B7A99A").opacity(0.2)
         }
     }

     private func moodTextColor(mood: String) -> Color {
          switch mood.lowercased() {
              case "anxious", "stressed", "overwhelmed", "angry": return Color.red.opacity(0.9)
              case "sad", "lonely", "down": return Color.blue.opacity(0.9)
              case "happy", "excited", "grateful", "joyful": return Color.green.opacity(0.9)
              case "calm", "relaxed", "peaceful": return Color.teal.opacity(0.9)
              case "tired", "exhausted": return Color.gray.opacity(0.9)
              default: return Color(hex: "#5C4433").opacity(0.8)
          }
     }
}

#Preview {
    NavigationView {
        InsightsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .onAppear {
                 // Add mock data to preview context
                 let context = PersistenceController.preview.container.viewContext
                 // ... (add mock JournalEntryCD objects with moods and keywords) ...
                 let entry1 = JournalEntryCD(context: context)
                 entry1.id = UUID(); entry1.createdAt = Date(); entry1.entryText = "Feeling happy today"; entry1.mood = "Happy"; entry1.keywords = "grateful, sunshine"
                 let entry2 = JournalEntryCD(context: context)
                 entry2.id = UUID(); entry2.createdAt = Date(); entry2.entryText = "Stressed about work"; entry2.mood = "Stressed"; entry2.keywords = "work, deadline, pressure"
                 let entry3 = JournalEntryCD(context: context)
                 entry3.id = UUID(); entry3.createdAt = Calendar.current.date(byAdding: .day, value: -1, to: Date()); entry3.entryText = "Feeling calm"; entry3.mood = "Calm"; entry3.keywords = "relax, peace, nature"
                 try? context.save()
             }
    }
    // Add SettingsViewModel needed by the view or its navigation context
    .environmentObject(SettingsViewModel())
} 