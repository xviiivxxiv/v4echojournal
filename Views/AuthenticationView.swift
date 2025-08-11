import SwiftUI
import AuthenticationServices // For Sign in with Apple button
import CryptoKit // For Apple Sign-In nonce handling

struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userJourney: UserJourneyManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView { // Wrap content in ScrollView to handle keyboard
                VStack(spacing: 20) {
                    
                    Text(isSignUp ? "Create Account" : "Welcome")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 40)
                    
                    Text(isSignUp ? "Join to start your journal" : "Sign in to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)

                    // Email & Password Fields
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    
                    if isSignUp {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    // Action Buttons
                    Button(action: isSignUp ? signUpWithEmail : signInWithEmail) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLoading || !isFormValid)
                    
                    Text("or")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 10)

                    // Sign in with Apple Button
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
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(10)
                    
                    // Toggle between Sign In/Sign Up
                    Button(action: {
                        isSignUp.toggle()
                        errorMessage = nil
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && 
                   password == confirmPassword && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    private func signInWithEmail() {
        Task {
            do {
                print("🔐 Starting email sign-in...")
                isLoading = true
                try await authService.signIn(email: email, password: password)
                print("✅ Email sign-in successful")
                
                await MainActor.run {
                    isLoading = false
                    userJourney.advance(to: .mainApp)
                    errorMessage = nil
                }
            } catch {
                print("❌ Email sign-in failed: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func signUpWithEmail() {
        Task {
            do {
                print("🔐 Starting email sign-up...")
                isLoading = true
                try await authService.signUp(email: email, password: password)
                print("✅ Email sign-up successful")
                
                await MainActor.run {
                    isLoading = false
                    userJourney.advance(to: .mainApp)
                    errorMessage = nil
                }
            } catch {
                print("❌ Email sign-up failed: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        print("🔐 Starting Apple sign-in...")
        await authService.handleSignInWithAppleCompletion(result)
        
        // Check if Apple sign-in was successful
        if authService.user != nil {
            print("✅ Apple sign-in successful")
            await MainActor.run {
                userJourney.advance(to: .mainApp)
            }
        } else {
            print("❌ Apple sign-in failed")
        }
    }
}

#Preview {
    AuthenticationView()
} 