import SwiftUI
import AuthenticationServices

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
        case .google: return "g.circle.fill" // Using SF Symbol
        case .facebook: return "f.cursive.circle.fill" // Using SF Symbol
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
            .signInWithAppleButtonStyle(.white) // Style for dark background
            .frame(height: 50)
            .cornerRadius(12)
        } else {
            Button(action: {
                handleSocialSignIn(provider: provider)
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
                    userJourney.advance(to: .accountCreated)
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
                    userJourney.advance(to: .accountCreated)
                }
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

#Preview {
    AccountCreationView()
        .environmentObject(AuthService())
        .environmentObject(UserJourneyManager.shared)
}
