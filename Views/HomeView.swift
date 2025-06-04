import SwiftUI
import CoreData

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel(
        transcriptionService: WhisperTranscriptionService.shared
    )
    @State private var navigationPath = NavigationPath()

    @State private var showConversation = false
    @State private var currentQuote: String = "Tap below to see a quote."
    private let quotes = [
        "The journey of a thousand miles begins with a single step.",
        "Believe you can and you're halfway there.",
        "Strive not to be a success, but rather to be of value.",
        "The mind is everything. What you think you become."
    ]
    @State private var currentDate: String = ""

    enum Tab {
        case journal, insights, entry, challenges, you
    }
    @State private var selectedTab: Tab = .entry
    private let estimatedTabBarVisualHeight: CGFloat = 75 // ADJUST THIS VALUE BY TESTING

    // DateFormatter for the modal's date display (NEW)
    private var toastDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, EEE" // e.g., May 8, Thu
        return formatter
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) { 
            Color.backgroundCream
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if selectedTab == .entry {
                        headerView
                            .padding(.bottom, 15)
                        quoteSection
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                    }
                    
                    mainContentView
                        .id(selectedTab)
                        .padding(.horizontal, 15)
                        .frame(maxWidth: .infinity, maxHeight: .infinity) 
                    
                    Spacer(minLength: 0) 
                }
                .padding(.bottom, estimatedTabBarVisualHeight) 

                VStack(spacing: 0) {
                Spacer()
                    bottomTabBar
                }
                 .ignoresSafeArea(.container, edges: .bottom) 

                // NEW: MODAL PRESENTATION LAYER (on top of everything else in this ZStack)
                if viewModel.showDateInteractionModal { // viewModel is the HomeViewModel instance
                    ZStack { // Root for modal: Blur + Content
                        LightBlurView(style: .systemUltraThinMaterialLight)
                            .ignoresSafeArea(.all) // Should now cover everything
                            .onTapGesture {
                                viewModel.showDateInteractionModal = false
                            }
                        
                        // Optional: Scrim layer
                        // Color.black.opacity(0.3).ignoresSafeArea(.all)

                        VStack(spacing: 0) { // Content Layer
                            Spacer()
                            if let validDate = viewModel.tappedDateForModal {
                                Text(validDate, formatter: toastDateFormatter)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.black.opacity(0.6))
                                    .padding(.bottom, 6)
                            }
                            ZStack { // Wrapper for DateInteractionModalView (your box)
                                DateInteractionModalView(
                                    selectedDate: viewModel.tappedDateForModal ?? Date(),
                                    entry: viewModel.entryForTappedDate,
                                    onDismiss: { viewModel.showDateInteractionModal = false },
                                    onCreateEntryTapped: { 
                                        print("HomeView: Create Entry tapped. Current tab: \(selectedTab)")
                                        selectedTab = .entry
                                        viewModel.tappedDateForModal = nil
                                        viewModel.entryForTappedDate = nil
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) { 
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                                                viewModel.showDateInteractionModal = false 
                                            }
                                        }
                                        print("HomeView: Switched to Entry tab. Modal dismissal scheduled with very short delay.")
                                    },
                                    onViewEntryTapped: { entryToView in // NEW: Implement navigation
                                        print("HomeView: View Entry tapped for entry ID: \(entryToView.id?.uuidString ?? "N/A")")
                                        // Dismiss modal first (with animation or immediately based on preference)
                                        // Option 1: Dismiss immediately then navigate
                                        // viewModel.showDateInteractionModal = false
                                        // navigationPath.append(entryToView)

                                        // Option 2: Navigate then let modal disappear (might be smoother if nav animation is quick)
                                        // navigationPath.append(entryToView)
                                        // viewModel.showDateInteractionModal = false 
                                        
                                        // Option 3: Coordinated dismissal and navigation (preferable)
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                                            viewModel.showDateInteractionModal = false
                                        }
                                        // Allow dismissal animation to start, then navigate.
                                        // Or, if flicker is an issue, navigate before modal fully gone.
                                        navigationPath.append(entryToView)
                                    }
                                )
                            }
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.92)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 5)
                            .padding(.bottom, 15) // Adjust this for lowness (e.g., 10, 15, 20)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    // Animation for the modal ZStack itself is now handled by the .animation on NavigationStack below.
                }
                // END OF NEW MODAL PRESENTATION LAYER
            }
            .navigationTitle(navigationTitleForSelectedTab())
            .navigationBarTitleDisplayMode(selectedTab == .entry ? .automatic : .inline) 
            .toolbar(selectedTab == .entry ? .hidden : .visible, for: .navigationBar) 
            // Animation for modal presentation tied to HomeViewModel state
            .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: viewModel.showDateInteractionModal)
            .navigationDestination(for: JournalEntryCD.self) { entryToView in
                JournalEntryDetailView(entry: entryToView)
            }
        }
        .onAppear {
            currentDate = formattedDate()
            if selectedTab == .entry {
                showRandomQuote()
            }
            viewModel.newlySavedEntry = nil
            }
        .onChange(of: viewModel.newlySavedEntry) { _, newEntry in
             showConversation = (newEntry != nil)
        }
        .fullScreenCover(isPresented: $showConversation) {
             if let entry = viewModel.newlySavedEntry {
                  NavigationView {
                       ConversationView(journalEntry: entry)
                  }
             }
         }
        .alert("No Internet Connection", isPresented: $viewModel.showOfflineAlert) {
            Button("OK") {}
        } message: {
            Text("GPT follow-ups require Wi-Fi or Mobile Data.")
                .font(.system(size: 14, weight: .regular, design: .default))
        }
    }

    // MARK: - UI Components
    private var headerView: some View {
        HStack {
            // Logo on the left
            Image("AppIcon") // Changed to AppIcon
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28) // Slightly increased frame for AppIcon
                // .cornerRadius(4) // Optionally add corner radius if it looks too square
                // .foregroundColor(Color.buttonBrown) // Uncomment if the AppIcon needs tinting

            Spacer()

            // Date in the center
            Text(currentDate)
                .font(.system(size: 17, weight: .medium, design: .default)) 
                .foregroundColor(Color.neutralGray) 
            
            Spacer()

            // Settings icon on the right
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .medium)) // Size of the icon
                    .foregroundColor(Color.buttonBrown) // Use brand color for interactive elements
            }
        }
        .padding(.horizontal) // Add horizontal padding to the HStack
        .padding(.top, 15)    // Retain top padding for notch clearance
        .frame(height: 44)    // Give the header a consistent height
    }
    
    private var quoteSection: some View {
        VStack(spacing: 12) {
            ZStack {
                let cloudWidth: CGFloat = 300
                let cloudHeight: CGFloat = 106
                createEllipse(cx: 90.5, cy: 23, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 90.5, cy: 23, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight) 
                createEllipse(cx: 81.5, cy: 53, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 163.5, cy: 65, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 100.5, cy: 60, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 129.5, cy: 53, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 183.5, cy: 53, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 231.5, cy: 53, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 231.5, cy: 53, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight) 
                createEllipse(cx: 146.5, cy: 23, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 202.5, cy: 23, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 250, cy: 23, rx: 29, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 45, cy: 23, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 27, cy: 60, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 55, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 81, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 125, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 166, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 195, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 227, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 250, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 266, cy: 53, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 28, cy: 42, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)
                createEllipse(cx: 273, cy: 37, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight)

                Text("“\(currentQuote)”")
                    .font(.system(size: 18, design: .default).italic()) 
                    .fontWeight(.regular) 
                    .foregroundColor(Color.backgroundCream) 
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30) 
                    .padding(.vertical, 15)   
                    .frame(maxWidth: 240) 
                    .transition(.opacity) 
                    .animation(.easeInOut(duration: 0.3), value: currentQuote) 
            }
            .frame(width: 300, height: 106) 
            .compositingGroup() 
            .shadow(color: Color.gray.opacity(0.2), radius: 7, x: 0, y: 4) 
            .frame(maxWidth: .infinity, alignment: .center) 

            Button("Show another quote") {
                showRandomQuote()
        }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(Color.buttonBrown)
            .underline()
            .padding(.top, 15) 
        }
    }

    private var mainJournalingArea: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Text("How is your day?")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(Color.primaryEspresso)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
            Spacer(minLength: 0)

            Text(viewModel.isRecording ? "Recording... Tap to stop" : "Tap the mic to start journaling")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(Color.secondaryTaupe)
                .multilineTextAlignment(.center)
                .padding(.bottom, 15)

            HStack(alignment: .center, spacing: 32) {
                Button {
                    print("Type button tapped")
                } label: {
                    VStack {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 28, design: .default))
                        Text("Type")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Color.buttonBrown)
                }
                .frame(width: 60)

                Button {
                    viewModel.toggleRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.buttonBrown)
                            .frame(width: 80, height: 80)
                        Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    print("Prompts button tapped")
                } label: {
                    VStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28, design: .default))
                        Text("Prompts")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Color.buttonBrown)
                }
                .frame(width: 60)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        // Increase maxHeight for the journaling card
        .frame(minHeight: UIScreen.main.bounds.height * 0.45, maxHeight: UIScreen.main.bounds.height * 0.62) 
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var mainContentView: some View {
        VStack {
            switch selectedTab {
            case .entry:
                entryScreenContent.padding(.horizontal) 
            case .journal:
                HistoryView()
            case .insights:
                InsightsView()
            case .challenges:
                ChallengesView()
            case .you:
                YouView(homeViewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) 
    }
    
    @ViewBuilder
    private var entryScreenContent: some View {
        VStack(spacing: 10) { 
            mainJournalingArea 
            if let errorMessage = viewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .font(.system(size: 14, weight: .regular, design: .default)) 
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 5) 
            } else if viewModel.isLoading {
                ProgressView()
                     .tint(Color.secondaryTaupe)
                     .padding(.top, 5)
            } 
        }
        .frame(maxHeight: .infinity, alignment: .top) 
    }

    private var bottomTabBar: some View {
        HStack {
            tabBarItem(iconName: "text.book.closed.fill", label: "Journal", tab: .journal)
            Spacer()
            tabBarItem(iconName: "chart.pie.fill", label: "Insights", tab: .insights)
            Spacer()
            tabBarItem(iconName: "mic.fill", label: "Entry", tab: .entry) 
            Spacer()
            tabBarItem(iconName: "flame.fill", label: "Challenges", tab: .challenges)
            Spacer()
            tabBarItem(iconName: "person.fill", label: "You", tab: .you)
        }
        .padding(.horizontal, 25)
        .padding(.top, 6) 
        // This padding ensures tab bar content is above home indicator / bottom edge
        .padding(.bottom, (UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0) + 5) // Added small 5pt base
        .background(.clear) 
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func tabBarItem(iconName: String, label: String, tab: Tab) -> some View {
        Button(action: {
            selectedTab = tab
            if tab == .entry { 
                showRandomQuote()
            }
        }) {
            VStack(spacing: 2) { 
                Image(systemName: iconName)
                    .font(selectedTab == tab ? .system(size: 22, weight: .bold, design: .rounded) : .system(size: 20, weight: .regular, design: .rounded))
                    .foregroundColor(selectedTab == tab ? Color.buttonBrown : Color.secondaryTaupe)
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(selectedTab == tab ? Color.buttonBrown : Color.secondaryTaupe)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }

    private func showRandomQuote() {
        currentQuote = quotes.randomElement() ?? "Keep journaling, keep growing."
    }
    
    @ViewBuilder
    private func createEllipse(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, cloudWidth: CGFloat, cloudHeight: CGFloat) -> some View {
        Ellipse()
            .fill(Color.buttonBrown) 
            .frame(width: rx * 2, height: ry * 2)
            .offset(x: cx - (cloudWidth / 2), y: cy - (cloudHeight / 2))
    }
    
    private func navigationTitleForSelectedTab() -> String {
        switch selectedTab {
        case .journal:
            return "My Journal"
        case .insights:
            return "Insights"
        case .entry:
            return "" 
        case .challenges:
            return "Challenges"
        case .you:
            return "You"
    }
}
}

#Preview {
        HomeView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
