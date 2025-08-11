import SwiftUI
import LocalAuthentication

struct WelcomeBackView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userJourney: UserJourneyManager
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isSigningIn = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    VStack(spacing: 10) {
                        Text("Welcome Back")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Sign in to continue your journey")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 20) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: signInWithEmail) {
                        if isSigningIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign In")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSigningIn || email.isEmpty || password.isEmpty)
                    
                    SignInWithAppleButton(.signIn) { request in
                        handleAppleSignIn(request: request)
                    } onCompletion: { result in
                        handleAppleSignInCompletion(result: result)
                    }
                    .frame(height: 50)
                    .signInWithAppleButtonStyle(.black)
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func signInWithEmail() {
        Task {
            do {
                print("🔐 Starting email sign-in (Welcome Back)...")
                isSigningIn = true
                try await authService.signIn(email: email, password: password)
                print("✅ Email sign-in successful (Welcome Back)")
                
                await MainActor.run {
                    isSigningIn = false
                    userJourney.advance(to: .mainApp)
                    errorMessage = nil
                }
            } catch {
                print("❌ Email sign-in failed (Welcome Back): \(error.localizedDescription)")
                await MainActor.run {
                    isSigningIn = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handleAppleSignIn(request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        request.nonce = sha256(nonce)
    }
    
    private func handleAppleSignInCompletion(result: Result<ASAuthorization, Error>) {
        Task {
            do {
                print("🔐 Starting Apple Sign-In (Welcome Back)...")
                try await authService.handleAppleSignIn(result: result)
                print("✅ Apple Sign-In successful (Welcome Back)")
                
                await MainActor.run {
                    userJourney.advance(to: .mainApp)
                    errorMessage = nil
                }
            } catch {
                print("❌ Apple Sign-In failed (Welcome Back): \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Apple Sign-In Helpers

import CryptoKit
import AuthenticationServices

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

#Preview {
    WelcomeBackView()
} 