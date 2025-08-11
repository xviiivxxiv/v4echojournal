import SwiftUI

struct OnboardingToneView: View {
    @EnvironmentObject var userJourney: UserJourneyManager
    private let persistenceManager = OnboardingPersistenceManager()

    let tones = [
        "Gentle & supportive 🌸",
        "Honest & challenging 🔍",
        "Fun & curious 🎈",
        "Deep & thoughtful 🌊"
    ]

    var body: some View {
        ZStack {
            Color.backgroundCream.ignoresSafeArea()

            VStack(alignment: .center, spacing: 25) {
                Spacer()

                Text("How should I respond to you?")
                    .font(.system(size: 34, weight: .regular, design: .default))
                    .foregroundColor(.primaryEspresso)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 15)

                ForEach(tones, id: \.self) { tone in
                    Button(action: { selectTone(tone) }) {
                        Text(tone)
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

    private func selectTone(_ tone: String) {
        print("Selected Tone: \(tone)")
        var onboardingData = persistenceManager.getOnboardingData()
        onboardingData.selectedTone = tone
        persistenceManager.saveOnboardingData(onboardingData)
        userJourney.advance(to: .dynamicAhaMoment)
    }
}

#Preview {
    OnboardingToneView()
        .environmentObject(UserJourneyManager.shared)
} 