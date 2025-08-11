import Foundation
import LocalAuthentication
import FirebaseAuth
import Combine

// MARK: - Authentication Flow Types
enum AuthenticationFlow {
    case newUser                    // No previous session
    case returningUserStayLoggedIn  // Skip all auth
    case returningUserFaceID        // Face ID required
    case returningUserPasscode      // Passcode required  
    case returningUserManual        // Manual sign-in required
}

enum LocalAuthenticationResult {
    case success
    case failed
    case cancelled
    case notAvailable
}

// MARK: - Authentication Flow Manager
@MainActor
class AuthenticationFlowManager: ObservableObject {
    static let shared = AuthenticationFlowManager()
    
    @Published var currentFlow: AuthenticationFlow = .newUser
    @Published var hasValidFirebaseSession: Bool = false
    @Published var firebaseSessionEmail: String? = nil
    @Published var isLocallyAuthenticated: Bool = false
    
    private let settings = SettingsManager.shared
    private var authService: AuthService?
    
    private init() {
        print("🔐 AuthenticationFlowManager initialized")
    }
    
    // MARK: - Public Methods
    
    func setAuthService(_ authService: AuthService) {
        self.authService = authService
    }
    
    func determineAuthenticationFlow() -> AuthenticationFlow {
        print("🔐 Determining authentication flow...")
        
        // Check if Firebase session exists first
        let hasFirebaseSession = authService?.user != nil
        hasValidFirebaseSession = hasFirebaseSession
        firebaseSessionEmail = authService?.user?.email
        
        print("🔐 Firebase session: \(hasFirebaseSession ? "✅" : "❌")")
        print("🔐 Settings - hasCompletedFullOnboarding: \(settings.hasCompletedFullOnboarding)")
        print("🔐 Settings - stayLoggedIn: \(settings.stayLoggedIn)")
        print("🔐 Settings - isFaceIDEnabled: \(settings.isFaceIDEnabled)")
        
        let isPasscodeSet = KeychainService.getPasscode() != nil
        print("🔐 Passcode set: \(isPasscodeSet)")
        
        // CRITICAL FIX: Check if this is a NEW USER completing onboarding for the FIRST TIME
        // vs a RETURNING USER who needs authentication
        
        if !settings.hasCompletedFullOnboarding {
            // User hasn't completed onboarding yet
            currentFlow = .newUser
            print("🔐 Flow: newUser (no onboarding)")
        } else if hasFirebaseSession && isLocallyAuthenticated {
            // User is already authenticated both ways - should show main app
            currentFlow = .returningUserStayLoggedIn
            print("🔐 Flow: returningUserStayLoggedIn (already authenticated)")
        } else if hasFirebaseSession && !isLocallyAuthenticated {
            // CRITICAL: This is where we need to distinguish NEW vs RETURNING
            
            // Check if user has "Stay Logged In" enabled
            if settings.stayLoggedIn {
                currentFlow = .returningUserStayLoggedIn
                print("🔐 Flow: returningUserStayLoggedIn (stay logged in enabled)")
            } else {
                // CRITICAL FIX: Check if this is a FIRST-TIME completion
                // If user just completed onboarding AND has Firebase session, 
                // they should go to MainTabView WITHOUT authentication
                
                if !hasEverRequiredAuthentication() {
                    // This is a NEW USER who just completed onboarding
                    // Mark them as locally authenticated and let them through
                    print("🔐 NEW USER: First time completing onboarding - granting access")
                    isLocallyAuthenticated = true
                    markAsHavingRequiredAuthentication()
                    currentFlow = .returningUserStayLoggedIn
                } else {
                    // This is a RETURNING USER who needs authentication
                    if settings.isFaceIDEnabled && isPasscodeSet {
                        currentFlow = .returningUserFaceID
                        print("🔐 Flow: returningUserFaceID (returning user)")
                    } else if isPasscodeSet {
                        currentFlow = .returningUserPasscode
                        print("🔐 Flow: returningUserPasscode (returning user)")
                    } else {
                        currentFlow = .returningUserManual
                        print("🔐 Flow: returningUserManual (returning user)")
                    }
                }
            }
        } else {
            // No Firebase session - need to authenticate
            currentFlow = .newUser
            print("🔐 Flow: newUser (no session)")
        }
        
        print("🔐 Determined flow: \(currentFlow)")
        return currentFlow
    }
    
    func authenticateWithFaceID() async -> LocalAuthenticationResult {
        print("🔐 Starting Face ID authentication...")
        
        let context = LAContext()
        var error: NSError?
        
        // Check if Face ID is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("🔐 Face ID not available: \(error?.localizedDescription ?? "Unknown error")")
            return .notAvailable
        }
        
        let reason = "Use Face ID to access your journal"
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if success {
                print("🔐 Face ID authentication succeeded")
                isLocallyAuthenticated = true
                return .success
            } else {
                print("🔐 Face ID authentication failed")
                return .failed
            }
        } catch {
            print("🔐 Face ID error: \(error.localizedDescription)")
            if (error as NSError).code == LAError.userCancel.rawValue {
                return .cancelled
            }
            return .failed
        }
    }
    
    func authenticateWithPasscode(_ enteredPasscode: String) -> LocalAuthenticationResult {
        print("🔐 Starting passcode authentication...")
        
        guard let savedPasscode = KeychainService.getPasscode() else {
            print("🔐 No saved passcode found")
            return .notAvailable
        }
        
        if savedPasscode == enteredPasscode {
            print("🔐 Passcode authentication succeeded")
            isLocallyAuthenticated = true
            return .success
        } else {
            print("🔐 Passcode authentication failed")
            return .failed
        }
    }
    
    func completeManualAuthentication() {
        print("🔐 Manual authentication completed")
        isLocallyAuthenticated = true
        hasValidFirebaseSession = authService?.user != nil
        firebaseSessionEmail = authService?.user?.email
    }
    
    func shouldShowMainApp() -> Bool {
        let hasFirebase = hasValidFirebaseSession
        let hasLocalAuth = isLocallyAuthenticated
        let hasOnboarding = settings.hasCompletedFullOnboarding
        
        print("🔍 shouldShowMainApp check:")
        print("   - hasValidFirebaseSession: \(hasFirebase ? "✅" : "❌")")
        print("   - isLocallyAuthenticated: \(hasLocalAuth ? "✅" : "❌")")
        print("   - hasCompletedFullOnboarding: \(hasOnboarding ? "✅" : "❌")")
        
        let result = hasFirebase && hasLocalAuth && hasOnboarding
        print("🔍 shouldShowMainApp = \(result)")
        return result
    }
    
    func resetAuthenticationState() {
        print("🔐 Resetting authentication state")
        isLocallyAuthenticated = false
        hasValidFirebaseSession = false
        firebaseSessionEmail = nil
        currentFlow = .newUser
    }
    
    // MARK: - Debug/Testing Methods
    
    func debugCurrentState() {
        print("🔐 AuthenticationFlowManager State:")
        print("   - currentFlow: \(currentFlow)")
        print("   - hasValidFirebaseSession: \(hasValidFirebaseSession)")
        print("   - firebaseSessionEmail: \(firebaseSessionEmail ?? "nil")")
        print("   - isLocallyAuthenticated: \(isLocallyAuthenticated)")
        print("   - hasEverRequiredAuthentication: \(hasEverRequiredAuthentication())")
    }
    
    func forceFlowReevaluation() {
        print("🔄 FORCE: Re-evaluating authentication flow...")
        let _ = determineAuthenticationFlow()
    }
    
    func simulateNewUser() {
        print("🧪 SIMULATE: New User")
        UserDefaults.standard.removeObject(forKey: "hasEverRequiredAuthentication")
        resetAuthenticationState()
        let _ = determineAuthenticationFlow()
    }
    
    func simulateReturningUser() {
        print("🧪 SIMULATE: Returning User")
        markAsHavingRequiredAuthentication()
        resetAuthenticationState()
        let _ = determineAuthenticationFlow()
    }
    
    func simulateReturningUserWithFaceID() {
        print("🧪 SIMULATE: Returning User with Face ID")
        markAsHavingRequiredAuthentication()
        resetAuthenticationState()
        let _ = determineAuthenticationFlow()
    }
    
    func simulateFirebaseSessionExpired() {
        print("🧪 Simulating Firebase session expired")
        hasValidFirebaseSession = false
        firebaseSessionEmail = nil
        isLocallyAuthenticated = false
    }
    
    // MARK: - New User vs Returning User Tracking
    
    private func hasEverRequiredAuthentication() -> Bool {
        return UserDefaults.standard.bool(forKey: "hasEverRequiredAuthentication")
    }
    
    private func markAsHavingRequiredAuthentication() {
        UserDefaults.standard.set(true, forKey: "hasEverRequiredAuthentication")
        print("🔐 Marked user as having required authentication (returning user)")
    }
} 