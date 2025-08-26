import SwiftUI
import SuperwallKit

struct AhaOnboardingView: View {
    @EnvironmentObject var userJourney: UserJourneyManager
    @StateObject private var viewModel = AhaOnboardingViewModel()
    
    // This flag will be set to true when the user proceeds from the paywall
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color
                Color.heardGrey.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Main content based on state
                    switch viewModel.currentState {
                    case .idle, .recording:
                        VStack(spacing: 0) {
                            // Top section - Text area (30% of screen)
                            VStack {
                                Spacer()
                                Text(viewModel.statusMessage)
                                    .font(.custom("nicky-laatz-very-vogue-display", size: 28))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .foregroundColor(.buttonBrown)
                                Spacer()
                            }
                            .frame(height: geometry.size.height * 0.30)
                            
                            // Middle section - Button area (40% of screen, button centered within)
                            VStack {
                                Spacer()
                                micButton
                                Spacer()
                            }
                            .frame(height: geometry.size.height * 0.40)
                            
                            // Bottom section - Soundwave area (30% of screen)
                            VStack {
                                Spacer()
                                if viewModel.isRecording {
                                    SoundWaveView(isRecording: viewModel.isRecording)
                                        .transition(.opacity.combined(with: .scale))
                                } else {
                                    // Invisible placeholder to maintain consistent spacing
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 92)
                                }
                                Spacer()
                            }
                            .frame(height: geometry.size.height * 0.30)
                        }
                    case .transcribing, .thinking:
                        // Return to original centered layout for thinking state
                        VStack {
                            Spacer()
                            Text(viewModel.statusMessage)
                                .font(.custom("nicky-laatz-very-vogue-display", size: 28))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .foregroundColor(.buttonBrown)
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding(.vertical, 40)
                            Spacer()
                        }
                    case .showingAhaMoment:
                        // Return to original layout for follow-up view
                        VStack {
                            Spacer()
                            Text("Mmmmhh... Interesting")
                                .font(.custom("GentyDemo-Regular", size: 28))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .foregroundColor(.buttonBrown)
                                .padding(.bottom, 20)
                            ahaMomentView
                            Spacer()
                        }
                    }
                }
            }
        }
        .onAppear {
            // Set up Superwall delegate and user identification
            setupSuperwall()
            viewModel.generateDynamicPrompt(from: userJourney)
            // The paywall is now presented after account creation by the UserJourneyManager.
        }
    }
    
    private var micButton: some View {
        Button(action: viewModel.handleMicButtonTapped) {
            Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(viewModel.isRecording ? .heardRecordButtonRed : .buttonBrown)
                .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: viewModel.isRecording)
        }
        .padding(40)
    }
    
    private var ahaMomentView: some View {
        VStack(spacing: 25) {
            if let userText = viewModel.transcribedText {
                // 2. User text bubble with heard cream background
                VStack(alignment: .leading, spacing: 8) {
                    Text("you said:")
                        .font(.custom("nicky-laatz-very-vogue-text", size: 12))
                        .foregroundColor(.buttonBrown)
                    Text(userText)
                        .font(.custom("nicky-laatz-very-vogue-text", size: 16))
                        .foregroundColor(.buttonBrown)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.backgroundCream) // heard cream background
                .cornerRadius(12)
            }
            
            if let aiQuestion = viewModel.aiFollowUpQuestion {
                // 3. AI response bubble with heard cream background and "heard says:"
                VStack(alignment: .leading, spacing: 8) {
                    Text("heard says:")
                        .font(.custom("nicky-laatz-very-vogue-text", size: 12))
                        .foregroundColor(.buttonBrown)
                    Text(aiQuestion)
                        .font(.custom("nicky-laatz-very-vogue-display", size: 18))
                        .foregroundColor(.buttonBrown)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.backgroundCream) // heard cream background
                .cornerRadius(12)
            }
            
            Spacer(minLength: 30)

            // New Call to Action
            Text("Reply here....")
                .font(.custom("nicky-laatz-very-vogue-text", size: 18))
                .foregroundColor(.buttonBrown)
            
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
    private let onDismiss: (() -> Void)?
    
    init(onPurchaseComplete: @escaping () -> Void, onDismiss: (() -> Void)? = nil) {
        self.onPurchaseComplete = onPurchaseComplete
        self.onDismiss = onDismiss
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
            // Call the dismiss handler if provided
            onDismiss?()
        default:
            break
        }
    }
}

#Preview {
    AhaOnboardingView()
} 