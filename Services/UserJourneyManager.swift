import Foundation
import Combine
import FirebaseAuth

// MARK: - App State Machine
enum AppState: String, CaseIterable {
    // New, more granular onboarding states
    case firstLaunch
    case welcome
    case onboardingGoal
    case onboardingTone
    case dynamicAhaMoment
    case preAccountCreation // New interstitial state

    // Existing states that will follow
    case accountCreationInProgress
    case accountCreated
    case paywallPresented
    case subscriptionActive
    case personalizationInProgress
    case fullyOnboarded
    
    // Core app states
    case returningUserAuth
    case mainApp
    
    var description: String {
        switch self {
        case .firstLaunch: return "First Launch"
        case .welcome: return "Welcome Screen"
        case .onboardingGoal: return "Onboarding: Goal"
        case .onboardingTone: return "Onboarding: Tone"
        case .dynamicAhaMoment: return "Onboarding: Dynamic Aha Moment"
        case .preAccountCreation: return "Pre-Account Creation Interstitial"
        case .paywallPresented: return "Paywall Presented"
        case .subscriptionActive: return "Subscription Active"
        case .accountCreationInProgress: return "Account Creation In Progress"
        case .accountCreated: return "Account Created"
        case .personalizationInProgress: return "Personalization In Progress"
        case .fullyOnboarded: return "Fully Onboarded"
        case .returningUserAuth: return "Returning User Auth"
        case .mainApp: return "Main App"
        }
    }
}

// MARK: - Recovery Actions
enum RecoveryAction {
    case retry
    case skipToNext
    case resetToBeginning
    case contactSupport
    case resumeFromLastValid
}

// MARK: - User Journey Manager
@MainActor
class UserJourneyManager: ObservableObject {
    static let shared = UserJourneyManager()
    
    @Published private(set) var currentState: AppState = .firstLaunch
    @Published private(set) var isRecovering: Bool = false
    @Published private(set) var lastError: String?
    
    private let persistenceManager = OnboardingPersistenceManager()
    private let settings = SettingsManager.shared
    private var authService: AuthService?
    
    private init() {
        print("🎯 UserJourneyManager initialized")
        loadPersistedState()
    }
    
    // MARK: - Public Methods
    
    func setAuthService(_ authService: AuthService) {
        self.authService = authService
    }
    
    func determineInitialState() -> AppState {
        print("🎯 Determining initial app state...")
        
        // 1. Check if the user is a fully onboarded, returning user
        if settings.hasCompletedFullOnboarding {
            print("🎯 Returning user detected")
            return .returningUserAuth
        }
        
        // 2. Fortified State Restoration: Check for partial onboarding progress
        let onboardingData = persistenceManager.getOnboardingData()
        
        if onboardingData.selectedTone != nil {
            print("🎯 Resuming from: Tone selected. Moving to Aha Moment.")
            return .dynamicAhaMoment
        }
        
        if onboardingData.selectedGoal != nil {
            print("🎯 Resuming from: Goal selected. Moving to Tone selection.")
            return .onboardingTone
        }
        
        if persistenceManager.getHasAcceptedTandC() {
             print("🎯 Resuming from: T&Cs accepted. Moving to Goal selection.")
             return .onboardingGoal
        }
        
        // 3. Default to the very beginning
        print("🎯 First-time user - starting from welcome screen.")
        return .welcome
    }
    
    func advance(to newState: AppState, context: [String: Any] = [:]) {
        print("🎯 Attempting to advance from \(currentState.description) to \(newState.description)")
        
        guard isValidTransition(from: currentState, to: newState) else {
            print("❌ Invalid transition from \(currentState) to \(newState)")
            handleInvalidTransition(to: newState, context: context)
            return
        }
        
        // Save state before transitioning
        persistenceManager.saveState(newState, context: context)
        
        // Perform transition
        let previousState = currentState
        currentState = newState
        
        print("✅ Successfully transitioned from \(previousState.description) to \(newState.description)")
        
        // Handle side effects
        handleStateTransition(from: previousState, to: newState, context: context)
    }
    
    func handleError(_ error: Error, context: [String: Any] = [:]) {
        print("❌ Error in state \(currentState.description): \(error.localizedDescription)")
        lastError = error.localizedDescription
        
        let recoveryAction = determineRecoveryAction(for: error, in: currentState)
        executeRecovery(recoveryAction, context: context)
    }
    
    func reset() {
        print("🔄 Resetting user journey to beginning")
        persistenceManager.clearAllData()
        currentState = .firstLaunch
        isRecovering = false
        lastError = nil
    }
    
    // MARK: - State Validation
    
    private func isValidTransition(from current: AppState, to next: AppState) -> Bool {
        switch (current, next) {
        // New Onboarding Flow
        case (.firstLaunch, .welcome): return true
        case (.welcome, .onboardingGoal): return true
        case (.onboardingGoal, .onboardingTone): return true
        case (.onboardingTone, .dynamicAhaMoment): return true
        case (.dynamicAhaMoment, .preAccountCreation): return true // <-- New Transition
        case (.preAccountCreation, .accountCreationInProgress): return true // <-- New Transition
            
        // Account creation flow
        case (.accountCreationInProgress, .accountCreated): return true
        
        // Paywall is now after account creation
        case (.accountCreated, .paywallPresented): return true // <-- New Transition
        case (.paywallPresented, .subscriptionActive): return true
        
        // Final steps
        case (.subscriptionActive, .personalizationInProgress): return true
        case (.personalizationInProgress, .fullyOnboarded): return true
        
        // Main app access
        case (.fullyOnboarded, .mainApp): return true
        case (.returningUserAuth, .mainApp): return true
        
        // Recovery transitions (always allowed)
        case (_, .firstLaunch): return true // Reset
        case (_, .returningUserAuth): return true // Force auth
        
        default:
            // Allow transition to self (for re-evaluation)
            if current == next { return true }
            return false
        }
    }
    
    private func handleInvalidTransition(to newState: AppState, context: [String: Any]) {
        print("⚠️ Handling invalid transition to \(newState.description)")
        
        // Determine recovery strategy
        if newState == .mainApp {
            // User trying to access main app - check prerequisites
            if !hasValidSubscription() {
                advance(to: .paywallPresented, context: context)
            } else if !hasValidAccount() {
                advance(to: .accountCreationInProgress, context: context)
            } else if !hasCompletedPersonalization() {
                advance(to: .personalizationInProgress, context: context)
            } else {
                // Force transition if all prerequisites met
                currentState = .mainApp
            }
        } else {
            // Log error and stay in current state
            lastError = "Invalid state transition attempted"
        }
    }
    
    // MARK: - State Side Effects
    
    private func handleStateTransition(from previous: AppState, to current: AppState, context: [String: Any]) {
        switch current {
        case .subscriptionActive:
            // Subscription activated - prepare for account creation
            persistenceManager.markSubscriptionActive()
            
        case .accountCreated:
            // Account created - sync all temporary data to Firebase
            persistenceManager.commitTemporaryDataToFirebase()
            
        case .fullyOnboarded:
            // Onboarding complete - mark in settings
            settings.hasCompletedFullOnboarding = true
            
        case .mainApp:
            // Clear any error states
            lastError = nil
            isRecovering = false
            
        default:
            break
        }
    }
    
    // MARK: - Recovery Logic
    
    private func determineRecoveryAction(for error: Error, in state: AppState) -> RecoveryAction {
        switch state {
        case .paywallPresented:
            return .retry // Retry payment
            
        case .accountCreationInProgress:
            return .retry // Retry account creation
            
        case .personalizationInProgress:
            return .skipToNext // Skip optional personalization
            
        case .returningUserAuth:
            return .retry // Retry authentication
            
        default:
            return .resumeFromLastValid
        }
    }
    
    private func executeRecovery(_ action: RecoveryAction, context: [String: Any]) {
        isRecovering = true
        
        switch action {
        case .retry:
            // Stay in current state, UI will handle retry
            break
            
        case .skipToNext:
            let nextState = getNextValidState(from: currentState)
            if let next = nextState {
                advance(to: next, context: context)
            }
            
        case .resetToBeginning:
            reset()
            
        case .contactSupport:
            // Set error state for support contact
            lastError = "Please contact support for assistance"
            
        case .resumeFromLastValid:
            if let lastValid = getLastValidState() {
                currentState = lastValid
            }
        }
        
        isRecovering = false
    }
    
    // MARK: - State Queries
    
    func shouldShowAhaOnboarding() -> Bool {
        // This view is now shown during the specific dynamicAhaMoment state
        return currentState == .dynamicAhaMoment
    }
    
    func shouldShowPaywall() -> Bool {
        return currentState == .paywallPresented
    }
    
    func shouldShowAccountCreation() -> Bool {
        return currentState == .accountCreationInProgress
    }
    
    func shouldShowPersonalization() -> Bool {
        return currentState == .personalizationInProgress
    }
    
    func shouldShowReturningUserAuth() -> Bool {
        return currentState == .returningUserAuth
    }
    
    func shouldShowMainApp() -> Bool {
        return currentState == .mainApp
    }
    
    // MARK: - Validation Helpers
    
    private func hasValidSubscription() -> Bool {
        return persistenceManager.hasActiveSubscription()
    }
    
    private func hasValidAccount() -> Bool {
        return authService?.user != nil
    }
    
    private func hasCompletedPersonalization() -> Bool {
        return settings.hasCompletedFullOnboarding
    }
    
    // MARK: - State Persistence
    
    private func loadPersistedState() {
        if let state = getPersistedState() {
            currentState = state
            print("🎯 Loaded persisted state: \(state.description)")
        }
    }
    
    private func getPersistedState() -> AppState? {
        return persistenceManager.getPersistedState()
    }
    
    private func getNextValidState(from current: AppState) -> AppState? {
        switch current {
        case .paywallPresented: return .subscriptionActive
        case .subscriptionActive: return .accountCreationInProgress
        case .accountCreationInProgress: return .accountCreated
        case .accountCreated: return .personalizationInProgress
        case .personalizationInProgress: return .fullyOnboarded
        case .fullyOnboarded: return .mainApp
        default: return nil
        }
    }
    
    private func getLastValidState() -> AppState? {
        return persistenceManager.getLastValidState()
    }
    
    // MARK: - Debug Methods
    
    func debugCurrentState() {
        print("🎯 UserJourneyManager State:")
        print("   - currentState: \(currentState.description)")
        print("   - isRecovering: \(isRecovering)")
        print("   - lastError: \(lastError ?? "none")")
        print("   - hasValidSubscription: \(hasValidSubscription())")
        print("   - hasValidAccount: \(hasValidAccount())")
        print("   - hasCompletedPersonalization: \(hasCompletedPersonalization())")
    }
} 