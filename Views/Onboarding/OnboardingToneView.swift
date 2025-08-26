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
            Color.heardGrey.ignoresSafeArea()

            VStack(alignment: .center, spacing: 25) {
                Spacer()

                Text("How should I respond to you?")
                    .font(.custom("GentyDemo-Regular", size: 34))
                    .foregroundColor(.buttonBrown)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 15)

                ForEach(tones, id: \.self) { tone in
                    Button(action: { selectTone(tone) }) {
                        Text(tone)
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