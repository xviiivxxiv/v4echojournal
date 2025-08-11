import Foundation
import Combine

// MARK: - Centralized Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - Published Properties
    @Published var stayLoggedIn: Bool {
        didSet {
            UserDefaults.standard.set(stayLoggedIn, forKey: "stayLoggedIn")
            print("🔧 SettingsManager: stayLoggedIn set to \(stayLoggedIn)")
        }
    }
    
    @Published var isFaceIDEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isFaceIDEnabled, forKey: "isFaceIDEnabled")
            print("🔧 SettingsManager: isFaceIDEnabled set to \(isFaceIDEnabled)")
        }
    }
    
    @Published var hasCompletedAhaOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedAhaOnboarding, forKey: "hasCompletedAhaOnboarding")
        }
    }
    
    @Published var hasCompletedFullOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedFullOnboarding, forKey: "hasCompletedFullOnboarding")
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Load values from UserDefaults
        self.stayLoggedIn = UserDefaults.standard.bool(forKey: "stayLoggedIn")
        self.isFaceIDEnabled = UserDefaults.standard.bool(forKey: "isFaceIDEnabled")
        self.hasCompletedAhaOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedAhaOnboarding")
        self.hasCompletedFullOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedFullOnboarding")
        
        print("🔧 SettingsManager initialized:")
        print("   - stayLoggedIn: \(stayLoggedIn)")
        print("   - isFaceIDEnabled: \(isFaceIDEnabled)")
        print("   - hasCompletedAhaOnboarding: \(hasCompletedAhaOnboarding)")
        print("   - hasCompletedFullOnboarding: \(hasCompletedFullOnboarding)")
    }
    
    // MARK: - Helper Methods
    func debugCurrentState() {
        print("🔧 SettingsManager Current State:")
        print("   - stayLoggedIn: \(stayLoggedIn)")
        print("   - isFaceIDEnabled: \(isFaceIDEnabled)")
        print("   - UserDefaults stayLoggedIn: \(UserDefaults.standard.bool(forKey: "stayLoggedIn"))")
        print("   - UserDefaults isFaceIDEnabled: \(UserDefaults.standard.bool(forKey: "isFaceIDEnabled"))")
    }
    
    func resetAllSettings() {
        stayLoggedIn = false
        isFaceIDEnabled = false
        hasCompletedAhaOnboarding = false
        hasCompletedFullOnboarding = false
        print("🔧 SettingsManager: All settings reset")
    }
    
    func resetForTesting() {
        // Reset all settings
        resetAllSettings()
        
        // Clear additional UserDefaults keys that might exist
        let keysToRemove = [
            "isOnboardingComplete",
            "selectedAIResponseTone", 
            "selectedIntention",
            "areRemindersEnabled",
            "reminderTime",
            "appUserID",
            "hasEverRequiredAuthentication"  // NEW: Reset returning user tracking
        ]
        
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        UserDefaults.standard.synchronize()
        print("🔧 SettingsManager: Complete reset for testing performed")
    }
} 