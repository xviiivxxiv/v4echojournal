import Foundation
import LocalAuthentication

@MainActor // Ensure callbacks run on the main thread for UI updates
class AuthenticationService {
    
    static let shared = AuthenticationService() // Singleton for easy access
    
    private init() {} // Private init for singleton
    
    /// Attempts to authenticate the user using biometrics (Face ID or Touch ID).
    /// - Parameter completion: A closure called with the authentication result.
    ///   - success: A boolean indicating whether authentication was successful.
    ///   - error: An optional error object if authentication failed or wasn't possible.
    func authenticateWithBiometrics(completion: @escaping (_ success: Bool, _ error: LAError?) -> Void) {
        let context = LAContext()
        var error: NSError?
        let reason = "Please authenticate to access your journal."

        // Check if the device is capable of biometric authentication
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            // Map NSError to LAError if possible, otherwise pass nil or a generic error
            let laError = error as? LAError
            completion(false, laError ?? LAError(.biometryNotAvailable))
            return
        }

        // Perform the biometric authentication
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
            // Ensure completion handler runs on the main thread
            DispatchQueue.main.async {
                if success {
                    print("Biometric authentication successful.")
                    completion(true, nil)
                } else {
                    let laError = authenticationError as? LAError
                    print("Biometric authentication failed: \(laError?.localizedDescription ?? "Unknown error")")
                    completion(false, laError ?? LAError(.authenticationFailed)) // Provide a default error if cast fails
                }
            }
        }
    }
    
    /// Checks if biometric authentication is available on the device.
    /// - Returns: A boolean indicating if biometrics can be evaluated.
    func isBiometricsAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
} 