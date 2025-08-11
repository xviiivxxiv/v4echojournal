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
            Color.backgroundCream.ignoresSafeArea()

            VStack(alignment: .center, spacing: 25) {
                Spacer()

                Text("So, what brings you to Heard?")
                    .font(.system(size: 34, weight: .regular, design: .default))
                    .foregroundColor(.primaryEspresso)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 15)

                ForEach(goals, id: \.self) { goal in
                    Button(action: { selectGoal(goal) }) {
                        Text(goal)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.backgroundCream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.buttonBrown)
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