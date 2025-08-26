import SwiftUI
import CoreData

struct HomeView: View {
    // This view now receives its ViewModel from the environment.
    @EnvironmentObject var viewModel: HomeViewModel
    @State private var navigationPath = NavigationPath()
    @State private var selectedChallengeForModal: Challenge?

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
            // 2. Apply conditional logic to the main background color
            (selectedTab == .journal ? Color(hex: "#5c4433") : Color.backgroundCream)
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if selectedTab == .entry {
                        // Header is now always visible on the Entry tab
                        headerView // Contains dropdown and settings
                        
                        // Date is now a separate, centered element
                        Text(currentDate)
                            .font(.system(size: 17, weight: .medium, design: .default))
                            .foregroundColor(Color.neutralGray)
                            .padding(.top, 4) // Adjust spacing as needed
                        
                        quoteSection
                            .padding(.horizontal)
                            .padding(.top, 10) // Adjust spacing from date
                            .padding(.bottom, 20)
                    }
                    
                    mainContentView
                        .id(selectedTab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity) 
                    
                    Spacer(minLength: 0) 
                }
                .padding(.bottom, 60) // 1. Re-introduce global bottom padding for content

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

                if let challenge = selectedChallengeForModal {
                    challengeDetailModal(for: challenge)
                }
            }
            .navigationTitle(navigationTitleForSelectedTab())
            .navigationBarTitleDisplayMode(selectedTab == .entry ? .automatic : .inline) 
            .toolbar(selectedTab == .entry || selectedTab == .you || selectedTab == .journal || selectedTab == .challenges ? .hidden : .visible, for: .navigationBar)
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
            viewModel.fetchActiveChallenges()
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
            // New Dropdown Menu for Journal Mode Selection
            Menu {
                ForEach(viewModel.availableModes, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.spring()) {
                            viewModel.selectedMode = mode
                        }
                    }) {
                        Label(headerTitle(for: mode), systemImage: iconName(for: mode))
                    }
                }
            } label: {
                HStack {
                    Image(systemName: iconName(for: viewModel.selectedMode))
                    Text(headerTitle(for: viewModel.selectedMode))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(viewModel.selectedMode.themeColor)
            }
            
            Spacer()

            // Date is no longer here
            
            Spacer()

            // Settings icon on the right
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color.buttonBrown)
            }
        }
        .padding(.horizontal)
        .padding(.top, 15)    
        .frame(height: 44)    
    }
    
    private var quoteSection: some View {
        VStack(spacing: 12) {
            ZStack {
                let cloudWidth: CGFloat = 300
                let cloudHeight: CGFloat = 106
                // Pass the dynamic theme color to the ellipses
                let themeColor = viewModel.selectedMode.themeColor
                
                createEllipse(cx: 90.5, cy: 23, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 90.5, cy: 23, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 81.5, cy: 53, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 163.5, cy: 65, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 100.5, cy: 60, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 129.5, cy: 53, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 183.5, cy: 53, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 231.5, cy: 53, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 231.5, cy: 53, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 146.5, cy: 23, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 202.5, cy: 23, rx: 36.5, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 250, cy: 23, rx: 29, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 45, cy: 23, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 27, cy: 60, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 55, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 81, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 125, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 166, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 195, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 227, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 250, cy: 83, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 266, cy: 53, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 28, cy: 42, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)
                createEllipse(cx: 273, cy: 37, rx: 27, ry: 23, cloudWidth: cloudWidth, cloudHeight: cloudHeight, color: themeColor)

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

    @ViewBuilder
    private var mainContentView: some View {
        VStack {
            switch selectedTab {
            case .entry:
                entryScreenContent
                    .padding(.horizontal)
            case .journal:
                HistoryView()
            case .insights:
                InsightsView()
                    .padding(.horizontal)
            case .challenges:
                ChallengesView(homeViewModel: viewModel, mainSelectedTab: $selectedTab, selectedChallengeForModal: $selectedChallengeForModal)
            case .you:
                YouView(homeViewModel: viewModel)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) 
    }
    
    @ViewBuilder
    private var entryScreenContent: some View {
        // The swipeable TabView
        TabView(selection: $viewModel.selectedMode) {
            ForEach(viewModel.availableModes, id: \.self) { mode in
                // The JournalingPageView no longer needs extra parameters
                JournalingPageView(
                    viewModel: viewModel,
                    mode: mode
                )
                .tag(mode)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: viewModel.requestedMode) { _, newRequestedMode in
            // When a deep link request comes in, update the selected mode
            if let newMode = newRequestedMode {
                viewModel.selectedMode = newMode
                // Reset the request so it can be triggered again
                viewModel.requestedMode = nil
            }
        }
    }

    private var bottomTabBar: some View {
        // 1. Determine colors based on the selected tab
        let isJournalTabActive = (selectedTab == .journal)
        
        let activeColor = isJournalTabActive ? Color(hex: "#fdf9f3") : Color.buttonBrown
        let inactiveColor = isJournalTabActive ? Color(hex: "#fdf9f3").opacity(0.7) : Color.secondaryTaupe
        let barBackgroundColor = isJournalTabActive ? Color(hex: "#5c4433") : Color.backgroundCream

        return HStack {
            // 3. Pass the determined colors to each tab bar item
            tabBarItem(iconName: "text.book.closed.fill", label: "Journal", tab: .journal, activeColor: activeColor, inactiveColor: inactiveColor)
            Spacer()
            tabBarItem(iconName: "chart.pie.fill", label: "Insights", tab: .insights, activeColor: activeColor, inactiveColor: inactiveColor)
            Spacer()
            tabBarItem(iconName: "mic.fill", label: "Entry", tab: .entry, activeColor: activeColor, inactiveColor: inactiveColor)
            Spacer()
            tabBarItem(iconName: "flame.fill", label: "Challenges", tab: .challenges, activeColor: activeColor, inactiveColor: inactiveColor)
            Spacer()
            tabBarItem(iconName: "person.fill", label: "You", tab: .you, activeColor: activeColor, inactiveColor: inactiveColor)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 5) // 2. Add aesthetic vertical padding inside the tab bar
        .padding(.bottom, (UIApplication.shared.windows.first { $0.isKeyWindow }?.safeAreaInsets.bottom ?? 0) + 5)
        .frame(maxWidth: .infinity)
        .background(barBackgroundColor)
    }

    // 2. Modify the tabBarItem function to accept colors as parameters
    @ViewBuilder
    private func tabBarItem(iconName: String, label: String, tab: Tab, activeColor: Color, inactiveColor: Color) -> some View {
        Button(action: {
            selectedTab = tab
            if tab == .entry { 
                showRandomQuote()
            }
        }) {
            VStack(spacing: 2) { 
                Image(systemName: iconName)
                    .font(selectedTab == tab ? .system(size: 22, weight: .bold, design: .rounded) : .system(size: 20, weight: .regular, design: .rounded))
                    .foregroundColor(selectedTab == tab ? activeColor : inactiveColor)
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(selectedTab == tab ? activeColor : inactiveColor)
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
    private func createEllipse(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, cloudWidth: CGFloat, cloudHeight: CGFloat, color: Color) -> some View {
        Ellipse()
            .fill(color) // Use the passed-in color
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
            // When entry tab is selected, show the specific mode's title
            switch viewModel.selectedMode {
            case .standard:
                return "Journal"
            case .challenge(let attempt, _):
                return viewModel.getChallenge(from: attempt)?.title ?? "Challenge"
            }
        case .challenges:
            return "Challenges"
        case .you:
            return "You"
        }
    }

    // MARK: - Helper functions moved from JournalModeSelectorView
    private func iconName(for mode: JournalEntryMode) -> String {
        switch mode {
        case .standard:
            return "book.fill"
        case .challenge:
            switch mode.challenge?.title {
            case "Gratitude 7-day Challenge": return "sun.max.fill"
            case "Love Challenge": return "heart.fill"
            case "Journaling Beginner Challenge": return "pencil.and.outline"
            default: return "star.fill"
            }
        }
    }

    private func headerTitle(for mode: JournalEntryMode) -> String {
        switch mode {
        case .standard:
            return "My Journal"
        case .challenge:
            switch mode.challenge?.title {
            case "Gratitude 7-day Challenge": return "Gratitude"
            case "Love Challenge": return "Love"
            case "Journaling Beginner Challenge": return "Beginner"
            default: return "Challenge"
            }
        }
    }

    @ViewBuilder
    private func challengeDetailModal(for challenge: Challenge) -> some View {
        ZStack {
            LightBlurView(style: .systemUltraThinMaterialLight)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        selectedChallengeForModal = nil
                    }
                }

            VStack {
                Spacer()
                ChallengeDetailView(
                    challenge: challenge,
                    viewModel: viewModel,
                    mainSelectedTab: $selectedTab,
                    dismissAction: {
                        withAnimation {
                            selectedChallengeForModal = nil
                        }
                    }
                )
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(challenge.gradient)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 20)
                .padding(.horizontal, 20)
                Spacer()
            }
        }
        .transition(.opacity.animation(.easeInOut))
    }
}

// MARK: - Standalone Helper Views and Extensions

struct ChallengeDaySelectorView: View {
    let duration: Int
    let completedDays: Set<Int>
    let selectedDayIndex: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<duration, id: \.self) { index in
                DayView(
                    dayNumber: index + 1,
                    isSelected: index == selectedDayIndex,
                    isCompleted: completedDays.contains(index + 1)
                )
                
                if index < duration - 1 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 15, height: 2)
                }
            }
        }
    }

    private struct DayView: View {
        let dayNumber: Int
        let isSelected: Bool
        let isCompleted: Bool

        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                    .background(isCompleted ? Circle().fill(Color.green.opacity(0.3)) : Circle().fill(Color.clear))
                    .frame(width: 30, height: 30)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Text("\(dayNumber)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .primary : .secondary)
                }
            }
        }
    }
}

// Add a safe subscript to Array to prevent crashes
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Add a computed property to ChallengeAttempt for easier day checking
extension ChallengeAttempt {
    var completedDaysSet: Set<Int> {
        guard let daysString = completedDays, !daysString.isEmpty else { return [] }
        return Set(daysString.split(separator: ",").compactMap { Int($0) })
    }
}

#Preview {
        HomeView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
