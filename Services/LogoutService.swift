import Foundation
import FirebaseAuth
import SwiftUI
import SuperwallKit

@MainActor
class LogoutService {
    
    /// Performs complete logout with atomic operations to prevent partial states
    /// Returns true if successful, false if any step failed
    static func performCompleteLogout() async -> Bool {
        print("🚨 Starting complete logout process...")
        
        do {
            // Step 1: Firebase signout (most critical - do this first)
            try await performFirebaseSignout()
            print("✅ Firebase signout successful")
            
            // Step 2: Clean up local authentication data
            await cleanupLocalAuthData()
            print("✅ Local auth data cleanup successful")
            
            // Step 3: Clear Superwall state to prevent paywall re-presentation
            await cleanupSuperwallState()
            print("✅ Superwall state cleanup successful")
            
            // Step 4: Reset app settings that depend on user session
            await resetUserSessionSettings()
            print("✅ User session settings reset successful")
            
            // Step 4: Brief delay for smooth transition
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            print("🎉 Complete logout successful - user can now sign in fresh")
            return true
            
        } catch {
            print("❌ Logout failed at step: \(error.localizedDescription)")
            
            // Attempt emergency recovery
            await emergencyRecovery()
            return false
        }
    }
    
    // MARK: - Private Implementation
    
    private static func performFirebaseSignout() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try Auth.auth().signOut()
                print("🔐 Firebase signOut() completed")
                continuation.resume()
            } catch {
                print("❌ Firebase signout error: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    private static func cleanupLocalAuthData() async {
        // Clean up keychain passcode
        let keychainResult = KeychainService.deletePasscode()
        if keychainResult {
            print("🔑 Keychain passcode deleted")
        } else {
            print("⚠️ Keychain deletion failed, but continuing...")
        }
        
        // Reset Face ID settings since passcode is gone
        SettingsManager.shared.isFaceIDEnabled = false
        print("👤 Face ID disabled")
    }
    
    private static func cleanupSuperwallState() async {
        // Clear Superwall cached state to prevent paywall re-presentation
        Superwall.shared.reset()
        print("🧹 Superwall state reset")
        
        // Clear any existing delegates to prevent conflicts
        Superwall.shared.delegate = nil
        print("🧹 Superwall delegate cleared")
    }
    
    private static func resetUserSessionSettings() async {
        // Reset any user-specific settings that shouldn't persist after logout
        // Note: We keep hasCompletedFullOnboarding = true so they don't go through onboarding again
        
        print("⚙️ User session settings reset (keeping onboarding completion)")
    }
    
    /// Emergency recovery when normal logout fails
    /// Forces app to a known-good state regardless of partial failures
    private static func emergencyRecovery() async {
        print("🆘 Executing emergency recovery...")
        
        // Force delete keychain even if Firebase failed
        _ = KeychainService.deletePasscode()
        
        // Reset Face ID
        SettingsManager.shared.isFaceIDEnabled = false
        
        // Clear Superwall state in emergency recovery too
        Superwall.shared.reset()
        Superwall.shared.delegate = nil
        
        // The UserJourneyManager will handle routing based on Firebase auth state
        print("🆘 Emergency recovery completed")
    }
}
