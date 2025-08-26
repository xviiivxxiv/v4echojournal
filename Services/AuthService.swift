import Foundation
import FirebaseAuth
import FirebaseCore // <-- FIX: Add this import
import CryptoKit // For Sign in with Apple
import AuthenticationServices // For Sign in with Apple
import GoogleSignIn
import FacebookLogin

@MainActor
class AuthService: ObservableObject {
    
    @Published var user: User?
    
    private var handle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String? // For Sign in with Apple

    init() {
        // Listen for authentication state changes
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }
    
    deinit {
        // Unregister the listener when the service is deinitialized
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Email & Password
    
    func signUp(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }
    
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    func sendSignInLink(to email: String, completion: @escaping (Error?) -> Void) {
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.url = URL(string: "https://v4echojournal.page.link/finishSignUp")
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.setIOSBundleID(Bundle.main.bundleIdentifier!)
        
        Auth.auth().sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings) { error in
            completion(error)
        }
    }
    
    // MARK: - Social Logins
    
    func signInWithGoogle() async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "AuthService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not find root view controller."])
        }

        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = gidSignInResult.user.idToken?.tokenString else {
            throw NSError(domain: "AuthService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Google ID token not found."])
        }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                         accessToken: gidSignInResult.user.accessToken.tokenString)
        
        try await Auth.auth().signIn(with: credential)
    }
    
    func signInWithFacebook(completion: @escaping (Error?) -> Void) {
        LoginManager().logIn(permissions: ["public_profile", "email"], from: nil) { result, error in
            if let error = error {
                completion(error)
                return
            }
            
            guard let result = result, !result.isCancelled else {
                let cancellationError = NSError(domain: "AuthService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Facebook login was cancelled."])
                completion(cancellationError)
                return
            }
            
            guard let accessToken = result.token else {
                let tokenError = NSError(domain: "AuthService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Facebook access token not found."])
                completion(tokenError)
                return
            }
            
            let credential = FacebookAuthProvider.credential(withAccessToken: accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, authError in
                if let authError = authError {
                    completion(authError)
                } else {
                    // Success
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Sign in with Apple
    
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .success(let auth):
            guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential else {
                throw NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not cast credential to ASAuthorizationAppleIDCredential"])
            }
            guard let nonce = currentNonce else {
                throw NSError(domain: "AuthService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid state: A login callback was received, but no login request was sent"])
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                throw NSError(domain: "AuthService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                throw NSError(domain: "AuthService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to serialize token string from data"])
            }
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            try await Auth.auth().signIn(with: credential)
            print("Apple sign-in successful.")
            
        case .failure(let error):
            print("Error: Sign in with Apple failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential else {
                print("Error: Could not cast credential to ASAuthorizationAppleIDCredential.")
                return
            }
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token.")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            do {
                try await Auth.auth().signIn(with: credential)
                print("Apple sign-in successful.")
            } catch {
                print("Error: Apple sign-in failed: \(error.localizedDescription)")
            }
            
        case .failure(let error):
            print("Error: Sign in with Apple failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign Out
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
    
    // MARK: - Private Helpers for Sign in with Apple
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
} 