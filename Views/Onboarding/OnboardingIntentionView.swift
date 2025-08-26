import SwiftUI

struct OnboardingIntentionView: View {
    @EnvironmentObject var userJourney: UserJourneyManager
    private let persistenceManager = OnboardingPersistenceManager()

    let goals = [
        "I want to reflect on my day 🪞",
        "I’m working on personal growth 🌱",
        "I’m processing thoughts & feelings 💭",
        "Other 👀"
    ]

    var body: some View {
        ZStack {
            Color.heardGrey.ignoresSafeArea()

            VStack(alignment: .center, spacing: 25) {
                Spacer()

                Text("So, what brings you to Heard?")
                    .font(.custom("GentyDemo-Regular", size: 34))
                    .foregroundColor(.buttonBrown)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 15)

                ForEach(goals, id: \.self) { goal in
                    Button(action: { selectGoal(goal) }) {
                        Text(goal)
                            .font(.custom("nicky-laatz-very-vogue-text", size: 18))
                            .fontWeight(.medium)
                            .foregroundColor(.buttonBrown)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(Color.buttonBrown.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal, 40)

                Spacer()
                Spacer()
            }
        }
    }

    private func selectGoal(_ goal: String) {
        print("Selected Goal: \(goal)")
        var onboardingData = persistenceManager.getOnboardingData()
        onboardingData.selectedGoal = goal
        persistenceManager.saveOnboardingData(onboardingData)
        userJourney.advance(to: .onboardingTone)
    }
}

#Preview {
    OnboardingIntentionView()
        .environmentObject(UserJourneyManager.shared)
} 