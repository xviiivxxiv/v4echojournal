import SwiftUI
import SuperwallKit

struct AhaOnboardingView: View {
    @StateObject private var viewModel = AhaOnboardingViewModel()
    
    // This flag will be set to true when the user proceeds from the paywall
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var userJourney: UserJourneyManager

    var body: some View {
        ZStack {
            // Background color
            Color.backgroundCream.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                
                // Title and status
                Text(viewModel.statusMessage)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundColor(.primaryEspresso) // Use brand color
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }

                // Main content based on state
                Group {
                    switch viewModel.currentState {
                    case .idle, .recording:
                        micButton
                    case .transcribing, .thinking:
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.vertical, 40)
                    case .showingAhaMoment:
                        ahaMomentView
                    }
                }
                
                Spacer()
                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Set up Superwall delegate and user identification
            setupSuperwall()
        }
    }
    
    private var micButton: some View {
        Button(action: viewModel.handleMicButtonTapped) {
            Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(viewModel.isRecording ? .red : .buttonBrown)
                .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: viewModel.isRecording)
        }
        .padding(40)
    }
    
    private var ahaMomentView: some View {
        VStack(alignment: .leading, spacing: 25) {
            if let userText = viewModel.transcribedText {
                VStack(alignment: .leading) {
                    Text("YOU SAID:")
                        .font(.caption)
                        .foregroundColor(.secondaryTaupe) // Use brand color
                    Text(userText)
                        .font(.body)
                        .foregroundColor(.primaryEspresso) // Use brand color
                }
            }
            
            if let aiQuestion = viewModel.aiFollowUpQuestion {
                 VStack(alignment: .leading) {
                     Text("AI FOLLOW-UP:")
                         .font(.caption)
                         .foregroundColor(.secondaryTaupe) // Use brand color
                     Text(aiQuestion)
                         .font(.title3)
                         .fontWeight(.bold)
                         .foregroundColor(.primaryEspresso) // Use brand color
                 }
            }
            
            Spacer(minLength: 30)

            // New Call to Action
            Text("Reply here...")
                .font(.headline)
                .foregroundColor(.secondaryTaupe)
            
            Button(action: {
                // Advance to the pre-account creation interstitial
                userJourney.advance(to: .preAccountCreation)
            }) {
                Image(systemName: "mic.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.buttonBrown)
            }
            .padding(.top, 10)
        }
        .padding()
        .background(Color.white.opacity(0.5))
        .cornerRadius(15)
    }
    
    // MARK: - Superwall Integration
    
    private func setupSuperwall() {
        // Set up Superwall delegate to handle purchase events
        Superwall.shared.delegate = SuperwallDelegateHandler { [self] in
            // This closure will be called when a successful purchase occurs
            DispatchQueue.main.async {
                print("🎉 Paywall purchase completed - advancing journey")
                settings.hasCompletedAhaOnboarding = true
                userJourney.advance(to: .subscriptionActive)
            }
        }
        
        // Identify the user for analytics (using a temporary ID for now)
        let temporaryUserID = "onboarding_user_\(UUID().uuidString)"
        Superwall.shared.identify(userId: temporaryUserID)
    }
    
    private func presentPaywall() {
        // This is no longer called from this view.
        // The UserJourneyManager will now show the paywall after account creation.
        userJourney.advance(to: .paywallPresented)
        
        // Present your "Heard Paywall - Test 1" template
        Superwall.shared.register(placement: "onboarding_aha_moment_reached")
    }
}

// MARK: - Superwall Delegate Handler

class SuperwallDelegateHandler: SuperwallDelegate {
    private let onPurchaseComplete: () -> Void
    
    init(onPurchaseComplete: @escaping () -> Void) {
        self.onPurchaseComplete = onPurchaseComplete
    }
    
    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        switch eventInfo.event {
        case .transactionComplete:
            // User completed a purchase
            onPurchaseComplete()
        case .transactionFail(let error):
            print("Transaction failed: \(error)")
        case .paywallClose:
            print("Paywall was closed")
        default:
            break
        }
    }
}

#Preview {
    AhaOnboardingView()
} 