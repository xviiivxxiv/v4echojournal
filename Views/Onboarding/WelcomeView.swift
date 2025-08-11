import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var userJourney: UserJourneyManager
    private let persistenceManager = OnboardingPersistenceManager()
    
    @State private var showPrivacyModal = false
    @State private var termsAccepted = false

    var body: some View {
        ZStack {
            // Main Content
            VStack(spacing: 20) {
                Spacer()

                Image("Heard Logo - transparent")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200)
                    .padding(.bottom, 10)

                Text("Because some things need to be heard.")
                    .font(.system(size: 18, weight: .regular, design: .default))
                    .foregroundColor(.primaryEspresso)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                Button(action: {
                    userJourney.advance(to: .onboardingGoal)
                }) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.backgroundCream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.buttonBrown)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
                .disabled(!termsAccepted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundCream)
            .ignoresSafeArea()

            // Dimmed background overlay
            if showPrivacyModal {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Optional: dismiss on tap outside
                    }
            }

            // Pop-up Modal
            if showPrivacyModal {
                PrivacyPolicyView(onAccept: {
                    persistenceManager.markTandCAccepted()
                    termsAccepted = true
                    withAnimation {
                        showPrivacyModal = false
                    }
                })
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: showPrivacyModal)
        .onAppear {
            if !persistenceManager.getHasAcceptedTandC() {
                // Use a slight delay to allow the main view to appear first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                       showPrivacyModal = true
                    }
                }
            } else {
                termsAccepted = true
            }
        }
    }
}

struct PrivacyPolicyView: View {
    var onAccept: () -> Void

    var body: some View {
        VStack(spacing: 25) {
            Text("T&C and Privacy Policy")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primaryEspresso)
            
            ScrollView {
                Text("""
                By pressing “Accept and continue,” you agree to our Terms of Use and Privacy Policy.

                Our app processes your voice data locally on your phone to transcribe reflections. This data is not stored on our servers.

                Some features use third-party AI tools. Please review our Privacy Policy for details.
                """)
                .font(.footnote)
                .foregroundColor(.secondaryTaupe)
            }
            
            Button(action: onAccept) {
                Text("Accept and continue")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.backgroundCream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.buttonBrown)
                    .clipShape(Capsule())
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: 550) // Constrain the height of the modal
        .background(Color.backgroundCream)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding(.horizontal, 40)
    }
}

#Preview {
    WelcomeView()
        .environmentObject(UserJourneyManager.shared)
} 