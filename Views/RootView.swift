import SwiftUI
import LocalAuthentication
import FirebaseAuth
import AuthenticationServices
import AppTrackingTransparency
import AdSupport

struct RootView: View {
    @StateObject private var authService = AuthService()
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var userJourney = UserJourneyManager.shared
    
    @State private var isInitialized = false
    
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
            // Superwall will present its own UI over this, so we just need a placeholder.
            loadingView("Loading offers...")
                .onAppear { print("📱 Showing: Placeholder for Superwall") }
            
        case .subscriptionActive:
            // Show brief transition or go directly to account creation
            loadingView("Setting up your account...")
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        userJourney.advance(to: .accountCreationInProgress)
                    }
                }
            
        case .accountCreationInProgress:
            AccountCreationView()
                .onAppear { print("📱 Showing: AccountCreationView") }
            
        case .accountCreated:
            // Show brief transition or go directly to personalization
            loadingView("Personalizing your experience...")
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        userJourney.advance(to: .personalizationInProgress)
                    }
                }
            
        case .personalizationInProgress:
            PersonalizationView()
                .onAppear { print("📱 Showing: PersonalizationView") }
            
        case .fullyOnboarded:
            // Show brief transition or go directly to main app
            loadingView("Welcome to EchoJournal!")
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        userJourney.advance(to: .mainApp)
                    }
                }
            
        // 3. Core App States
        case .returningUserAuth:
            ReturningUserAuthView()
                .onAppear { print("📱 Showing: ReturningUserAuthView") }
            
        case .mainApp:
            MainTabView()
                .onAppear { print("📱 Showing: MainTabView") }
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
                // Account creation succeeded
                userJourney.advance(to: .accountCreated)
                
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
        switch self {
        case .apple: return .white
        case .google: return .white
        case .facebook: return Color(red: 24/255, green: 119/255, blue: 242/255)
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .apple, .google: return .black
        case .facebook: return .white
        }
    }
}

struct SocialSignInButton: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userJourney: UserJourneyManager
    
    var provider: SocialProvider
    
    var body: some View {
        if provider == .apple {
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
            .frame(height: 50)
            .cornerRadius(12)
        } else {
            Button(action: {
                handleSocialSignIn()
            }) {
                HStack {
                    Image(systemName: provider.iconName)
                        .font(.title2)
                    Text(provider.title)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(provider.backgroundColor)
                .foregroundColor(provider.foregroundColor)
                .cornerRadius(12)
            }
        }
    }
    
    private func handleSocialSignIn() {
        Task {
            do {
                switch provider {
                case .apple:
                    break
                case .google:
                    try await authService.signInWithGoogle()
                case .facebook:
                    authService.signInWithFacebook { error in
                        if let error = error {
                            print("❌ Social sign in failed for \(provider): \(error.localizedDescription)")
                        } else {
                            userJourney.advance(to: .accountCreated)
                        }
                    }
                }
                
                if provider != .facebook {
                    await MainActor.run {
                        userJourney.advance(to: .accountCreated)
                    }
                }
            } catch {
                print("❌ Social sign in failed for \(provider): \(error.localizedDescription)")
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        do {
            try await authService.handleAppleSignIn(result: result)
            await MainActor.run {
                userJourney.advance(to: .accountCreated)
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
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Details")) {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section(header: Text("Create a Password")) {
                    SecureField("Password", text: $password)
                    SecureField("Confirm Password", text: $confirmPassword)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: createAccount) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Create Account")
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                }
            }
            .navigationTitle("Sign Up with Email")
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty &&
        password == confirmPassword && password.count >= 6
    }
    
    private func createAccount() {
        isLoading = true
        errorMessage = nil
        
        let persistenceManager = OnboardingPersistenceManager()
        var onboardingData = persistenceManager.getOnboardingData()
        onboardingData.userName = name
        persistenceManager.saveOnboardingData(onboardingData)
        
        Task {
            do {
                try await authService.signUp(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    userJourney.advance(to: .accountCreated)
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
            
            // Dimming Overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Header
                VStack(spacing: 10) {
                    Text("Create Your Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Join thousands of others on their reflection journey.")
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Social Login Buttons
                VStack(spacing: 15) {
                    SocialSignInButton(provider: .apple)
                    SocialSignInButton(provider: .google)
                    SocialSignInButton(provider: .facebook)
                    
                    Button(action: {
                        showEmailSignUp = true
                    }) {
                        Text("Continue with Email")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
                
                // Terms and Conditions Footer
                Text("By continuing, you agree to our [Terms of Use](https://www.example.com/terms) and [Privacy Policy](https://www.example.com/privacy).")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpView()
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