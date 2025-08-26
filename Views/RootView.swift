import SwiftUI
import LocalAuthentication
import FirebaseAuth
import AuthenticationServices
import AppTrackingTransparency
import AdSupport
import SuperwallKit

struct RootView: View {
    @StateObject private var authService = AuthService()
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var userJourney = UserJourneyManager.shared
    // Use @State for the optional ViewModel. It will be created manually.
    @State private var homeViewModel: HomeViewModel? = nil
    
    @State private var isInitialized = false
    @State private var isHomeReady = false
    
    var body: some View {
        Group {
            if !isInitialized {
                loadingView("Initializing...")
            } else {
                mainContent
            }
        }
        .environmentObject(authService)
        .environmentObject(settings)
        .environmentObject(userJourney)
        // Conditionally apply the environment object only when it's non-nil.
        .if(homeViewModel != nil) { view in
            view.environmentObject(homeViewModel!)
        }
        .onAppear {
            requestTrackingPermission()
            initializeApp()
        }
        .onChange(of: authService.user) { _, user in
            handleFirebaseSessionChange(user: user)
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch userJourney.currentState {
            
        // 1. New Onboarding Flow
        case .firstLaunch:
            // This state should immediately transition to welcome.
            loadingView("Starting...")
                .onAppear { userJourney.advance(to: .welcome) }
            
        case .welcome:
            WelcomeView()
                .onAppear { print("📱 Showing: WelcomeView") }
            
        case .onboardingGoal:
            OnboardingIntentionView()
                .onAppear { print("📱 Showing: OnboardingIntentionView (as Goal)") }
            
        case .onboardingTone:
            OnboardingToneView()
                .onAppear { print("📱 Showing: OnboardingToneView") }
            
        case .dynamicAhaMoment:
            AhaOnboardingView()
                .onAppear { print("📱 Showing: AhaOnboardingView (Dynamic)") }
            
        case .preAccountCreation:
            loadingView("Let's set up your account to save this conversation...")
                .onAppear {
                    print("📱 Showing: Pre-Account Creation Interstitial")
                    // Automatically advance to the account creation screen after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        userJourney.advance(to: .accountCreationInProgress)
                    }
                }
            
        // 2. Paywall and Account Creation
        case .paywallPresented:
            // Show the same loading view as the next state for seamless transition
            loadingView("Setting up your account...")
                .onAppear { 
                    print("📱 Showing: Placeholder for Superwall")
                    
                    // Set up Superwall delegate to handle dismissal
                    Superwall.shared.delegate = SuperwallDelegateHandler { 
                        // Purchase complete handler
                        DispatchQueue.main.async {
                            print("🎉 Paywall purchase completed - advancing journey")
                            userJourney.advance(to: .subscriptionActive)
                        }
                    } onDismiss: {
                        // Paywall dismissed without purchase
                        DispatchQueue.main.async {
                            print("❌ Paywall dismissed - continuing to account setup")
                            // Skip subscription and go directly to account setup
                            userJourney.advance(to: .fullyOnboarded)
                        }
                    }
                }
            
        case .subscriptionActive:
            // Show brief transition before advancing to the final onboarding step.
            loadingView("Setting up your account...")
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        userJourney.advance(to: .fullyOnboarded)
                    }
                }
            
        case .accountCreationInProgress:
            AccountCreationView()
                .onAppear { print("📱 Showing: AccountCreationView") }
            
        case .accountCreated:
            // This is a transitional state. The UserJourneyManager handles the next step.
            loadingView("Finalizing account...")
            
        case .fullyOnboarded:
            // This view now initializes the HomeViewModel and waits for it to be ready.
            loadingView("Setting up your account...")
                .onAppear {
                    if homeViewModel == nil && !isHomeReady {
                        // Create the view model only when we enter this state.
                        homeViewModel = HomeViewModel(transcriptionService: WhisperTranscriptionService.shared)
                        
                        // Wait a moment for the view to settle, then fetch
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            homeViewModel?.fetchActiveChallenges()
                            // Set ready after a brief delay to ensure everything is loaded
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isHomeReady = true
                            }
                        }
                    }
                }
                .onChange(of: isHomeReady) { _, ready in
                    if ready {
                        userJourney.advance(to: .mainApp)
                    }
                }
            
        // 3. Core App States
        case .returningUserAuth:
            ReturningUserAuthView()
                .onAppear { print("📱 Showing: ReturningUserAuthView") }
            
        case .mainApp:
            // The MainTabView will now pull the homeViewModel from the environment.
            // A non-nil check is performed here to ensure it exists before showing the view.
            if homeViewModel != nil {
                MainTabView()
                    .onAppear { print("📱 Showing: MainTabView") }
            } else {
                // This fallback provides a safe view if the ViewModel isn't ready,
                // preventing a crash.
                loadingView("Loading...")
            }
        }
    }
    
    private func requestTrackingPermission() {
        ATTrackingManager.requestTrackingAuthorization { status in
            switch status {
            case .authorized:
                // Tracking authorization dialog was shown and user authorized.
                print("✅ ATTrackingManager: Authorized")
            case .denied:
                // Tracking authorization dialog was shown and user denied.
                print("❌ ATTrackingManager: Denied")
            case .notDetermined:
                // Tracking authorization dialog has not been shown.
                print("🤔 ATTrackingManager: Not Determined")
            case .restricted:
                // The device is restricted from tracking and user cannot grant authorization.
                print("🚫 ATTrackingManager: Restricted")
            @unknown default:
                print("🤷 ATTrackingManager: Unknown")
            }
        }
    }
    
    private func loadingView(_ message: String) -> some View {
        VStack(spacing: 40) { // Increased spacing
            ThinkingAnimationView()
                .frame(height: 100) // Give the animation view a consistent frame
            
            Text(message)
                .font(.title3) // Slightly larger font
                .fontWeight(.medium)
                .foregroundColor(.primaryEspresso)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundCream)
        .ignoresSafeArea()
    }
    
    // MARK: - Initialization
    
    private func initializeApp() {
        guard !isInitialized else { return }
        
        print("🚀 Initializing app with state machine architecture...")
        
        // Set up services
        userJourney.setAuthService(authService)
        
        // Debug current state
        settings.debugCurrentState()
        userJourney.debugCurrentState()
        
        // Determine initial state
        let initialState = userJourney.determineInitialState()
        if initialState != userJourney.currentState {
            userJourney.advance(to: initialState)
        }
        
        // Mark as initialized
        isInitialized = true
        
        print("✅ App initialization complete - State: \(userJourney.currentState.description)")
    }
    
    private func handleFirebaseSessionChange(user: User?) {
        print("🔐 Firebase session change: \(user != nil ? "User present" : "User nil")")
        
        if let user = user {
            print("🔐 Firebase user: \(user.email ?? "no email")")
            
            // Handle session restoration based on current state
            switch userJourney.currentState {
            case .accountCreationInProgress:
                // Account creation succeeded, let the manager handle the next step
                userJourney.handleAccountCreated()
                
            case .returningUserAuth:
                // Returning user authenticated via Firebase - still need local auth
                break
                
            default:
                // Other states - session restoration doesn't change flow
                break
            }
        } else {
            // User logged out
            if userJourney.currentState == .mainApp {
                // Force back to auth if user was in main app
                userJourney.advance(to: .returningUserAuth)
            }
        }
    }
}

// Helper ViewModifier to apply modifiers conditionally
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Account Creation View
struct AccountCreationView: View {
    @State private var showEmailSignUp = false

    var body: some View {
        ZStack {
            // Background Image
            Image("Heard Onboarding - Background Image")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // Bottom gradient for darker button area
            VStack {
                Spacer()
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.5)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: UIScreen.main.bounds.height * 0.5)
                .ignoresSafeArea()
            }
            
            VStack {
                Spacer()
                
                // Header with refined spacing
                VStack(spacing: 20) {
                    Image("Heard Logo - transparent")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 160)

                    VStack(spacing: 8) {
                        Text("Create Your Account")
                            .font(.custom("GentyDemo-Regular", size: 42))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundColor(.white)
                        
                        Text("Join thousands of others on their reflection journey.")
                            .font(.custom("VeryVogueDisplay", size: 22))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
                
                Spacer()
                
                // Social Login Buttons with Facetune styling
                VStack(spacing: 12) {
                    SocialSignInButton(provider: .apple)
                    SocialSignInButton(provider: .google)
                    SocialSignInButton(provider: .facebook)
                    
                    // Email button with matching style
                    Button(action: {
                        showEmailSignUp = true
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18))
                                .frame(width: 24)
                            
                            Text("Continue with Email")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(50)  // Fully rounded pill shape
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
                
                // Terms and Conditions Footer
                Text("By continuing, you agree to our [Terms of Use](https://www.example.com/terms) and [Privacy Policy](https://www.example.com/privacy).")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpView()
        }
    }
}
// MARK: - Social Provider Enum and Button
enum SocialProvider {
    case apple, google, facebook
    
    var title: String {
        switch self {
        case .apple: return "Continue with Apple"
        case .google: return "Continue with Google"
        case .facebook: return "Continue with Facebook"
        }
    }
    
    var iconName: String {
        switch self {
        case .apple: return "apple.logo"
        case .google: return "g.circle.fill"
        case .facebook: return "f.cursive.circle.fill"
        }
    }
    
    var backgroundColor: Color {
        return .white
    }
    
    var foregroundColor: Color {
        return .black
    }
}

struct SocialSignInButton: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userJourney: UserJourneyManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var provider: SocialProvider
    
    var body: some View {
        if provider == .apple {
            // Use native SignInWithAppleButton with custom overlay for consistent styling
            ZStack {
                // Background matching other buttons
                RoundedRectangle(cornerRadius: 50)  // Fully rounded pill shape
                    .fill(Color.white)
                    .frame(height: 50)
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                
                SignInWithAppleButton(
                    onRequest: { request in
                        authService.handleSignInWithAppleRequest(request)
                    },
                    onCompletion: { result in
                        Task {
                            await handleAppleSignIn(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 44) // Slightly smaller to fit inside
                .clipShape(RoundedRectangle(cornerRadius: 50))  // Match pill shape
                .padding(.horizontal, 3) // Small padding from edges
            }
            .frame(height: 50)
        } else {
            Button(action: {
                handleSocialSignIn(provider: provider)
            }) {
                HStack {
                    // Custom icon styling
                    Group {
                        if provider == .google {
                            // Google "G" icon
                            Text("G")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 66/255, green: 133/255, blue: 244/255))
                        } else if provider == .facebook {
                            // Facebook "f" icon
                            Text("f")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color(red: 24/255, green: 119/255, blue: 242/255))
                        }
                    }
                    .frame(width: 24)
                    
                    Text(provider.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(50)  // Fully rounded pill shape
                .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
            }
        }
    }
    
    private func handleSocialSignIn(provider: SocialProvider) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if provider == .google {
                    try await authService.signInWithGoogle()
                }
                
                // UI updates must be on the main thread
                await MainActor.run {
                    isLoading = false
                    userJourney.handleAccountCreated()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
        
        if provider == .facebook {
            authService.signInWithFacebook { error in
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    userJourney.handleAccountCreated()
                }
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        do {
            try await authService.handleAppleSignIn(result: result)
            await MainActor.run {
                userJourney.handleAccountCreated()
            }
        } catch {
            print("❌ Apple sign in failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Email Sign Up View (Presented as Sheet)
struct EmailSignUpView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userJourney: UserJourneyManager
    @Environment(\.dismiss) var dismiss
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Create your account with email")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    TextField("email@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: createAccount) {
                        Text("Create Account")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                    }
                    .disabled(!isFormValid || isLoading)
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Sign Up with Email")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(leading: Button("Cancel") { dismiss() })
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
    }
    
    private func createAccount() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.signUp(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    print("✅ Email account created successfully.")
                    // The session change handler in RootView will advance the journey
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Personalization View
struct PersonalizationView: View {
    @EnvironmentObject var userJourney: UserJourneyManager
    
    @State private var selectedTone: String = ""
    @State private var selectedIntention: String = ""
    @State private var remindersEnabled: Bool = false
    @State private var reminderTime: Date = Date()
    
    private let toneOptions = ["Supportive", "Direct", "Curious", "Gentle"]
    private let intentionOptions = ["Daily Reflection", "Goal Setting", "Emotional Processing", "Gratitude Practice"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Text("Personalize Your Experience")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Help us tailor your reflection journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("How would you like me to respond?")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                        ForEach(toneOptions, id: \.self) { tone in
                            Button(tone) {
                                selectedTone = tone
                            }
                            .buttonStyle(SelectionButtonStyle(isSelected: selectedTone == tone))
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("What's your main intention?")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 10) {
                        ForEach(intentionOptions, id: \.self) { intention in
                            Button(intention) {
                                selectedIntention = intention
                            }
                            .buttonStyle(SelectionButtonStyle(isSelected: selectedIntention == intention))
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Daily Reminders")
                        .font(.headline)
                    
                    Toggle("Enable daily reminders", isOn: $remindersEnabled)
                    
                    if remindersEnabled {
                        DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                    }
                }
                
                Button("Complete Setup") {
                    completePersonalization()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedTone.isEmpty || selectedIntention.isEmpty)
                
                Spacer()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadExistingData()
        }
    }
    
    private func loadExistingData() {
        let persistenceManager = OnboardingPersistenceManager()
        let onboardingData = persistenceManager.getOnboardingData()
        
        if let tone = onboardingData.selectedTone {
            selectedTone = tone
        }
        
        if let intention = onboardingData.selectedIntention {
            selectedIntention = intention
        }
        
        if let reminderSettings = onboardingData.reminderSettings {
            remindersEnabled = reminderSettings.isEnabled
            if let time = reminderSettings.time {
                reminderTime = time
            }
        }
    }
    
    private func completePersonalization() {
        // Save personalization data
        let persistenceManager = OnboardingPersistenceManager()
        var onboardingData = persistenceManager.getOnboardingData()
        
        onboardingData.selectedTone = selectedTone
        onboardingData.selectedIntention = selectedIntention
        onboardingData.reminderSettings = OnboardingData.ReminderSettings(
            isEnabled: remindersEnabled,
            time: remindersEnabled ? reminderTime : nil
        )
        
        persistenceManager.saveOnboardingData(onboardingData)
        
        print("✅ Personalization complete")
        userJourney.advance(to: .fullyOnboarded)
    }
}

struct SelectionButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Returning User Auth View
struct ReturningUserAuthView: View {
    @EnvironmentObject var userJourney: UserJourneyManager
    @EnvironmentObject var settings: SettingsManager
    @State private var showingPasscodeEntry = false
    @State private var showingManualSignIn = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Text("Welcome Back")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Please authenticate to continue")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 20) {
                if settings.isFaceIDEnabled && KeychainService.getPasscode() != nil {
                    Button("Use Face ID") {
                        authenticateWithFaceID()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                if KeychainService.getPasscode() != nil {
                    Button("Use Passcode") {
                        showingPasscodeEntry = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                Button("Sign In Manually") {
                    showingManualSignIn = true
                }
                .buttonStyle(.borderless)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Auto-attempt Face ID if enabled
            if settings.isFaceIDEnabled && KeychainService.getPasscode() != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticateWithFaceID()
                }
            }
        }
        .sheet(isPresented: $showingPasscodeEntry) {
            PasscodeEntryView(
                title: "Enter Passcode",
                onSuccess: {
                    showingPasscodeEntry = false
                    userJourney.advance(to: .mainApp)
                },
                onCancel: {
                    showingPasscodeEntry = false
                }
            )
        }
        .sheet(isPresented: $showingManualSignIn) {
            WelcomeBackView()
        }
    }
    
    private func authenticateWithFaceID() {
        Task {
            let context = LAContext()
            let reason = "Use Face ID to access your journal"
            
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success {
                    await MainActor.run {
                        userJourney.advance(to: .mainApp)
                    }
                }
            } catch {
                print("Face ID failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Passcode Entry View
struct PasscodeEntryView: View {
    let title: String
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
    @State private var enteredPasscode = ""
    @State private var isShaking = false
    @State private var errorMessage = ""
    
    private let maxDigits = 4
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.medium)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                PasscodeIndicator(passcode: enteredPasscode)
                    .shake(isShaking)
                
                NumberPad { digit in
                    addDigit(digit)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private func addDigit(_ digit: String) {
        guard enteredPasscode.count < maxDigits else { return }
        
        if digit == "⌫" {
            if !enteredPasscode.isEmpty {
                enteredPasscode.removeLast()
            }
        } else {
            enteredPasscode += digit
            
            if enteredPasscode.count == maxDigits {
                validatePasscode()
            }
        }
    }
    
    private func validatePasscode() {
        guard let storedPasscode = KeychainService.getPasscode() else {
            errorMessage = "No passcode found"
            shakeAndReset()
            return
        }
        
        if enteredPasscode == storedPasscode {
            onSuccess()
        } else {
            errorMessage = "Incorrect passcode"
            shakeAndReset()
        }
    }
    
    private func shakeAndReset() {
        withAnimation(.default) {
            isShaking = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isShaking = false
            enteredPasscode = ""
        }
    }
}

#Preview {
    RootView()
} 