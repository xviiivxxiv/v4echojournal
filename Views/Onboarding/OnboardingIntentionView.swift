import SwiftUI

struct OnboardingIntentionView: View {
    // Action to proceed to the next onboarding step (Tone selection)
    var onIntentionSelected: (String) -> Void // Pass the selected intention
    // Action to skip onboarding
    var onSkip: () -> Void

    let intentions = [
        "Understand my feelings",
        "Process a situation",
        "Check in with myself",
        "Just need to vent"
    ]

    var body: some View {
        ZStack {
            Color.backgroundCream.ignoresSafeArea()

            VStack(alignment: .center, spacing: 25) {
                Spacer()

                Text("What brings you here today?")
                    .font(.system(size: 34, weight: .regular, design: .default)) // SF Pro
                    .foregroundColor(.primaryEspresso)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 15)

                ForEach(intentions, id: \.self) { intention in
                    Button(action: { onIntentionSelected(intention) }) {
                        Text(intention)
                            .font(.system(size: 18, weight: .medium, design: .rounded)) // SF Pro Rounded
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
                Spacer() // Extra spacer to push content up slightly

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.system(size: 16, weight: .regular, design: .rounded)) // SF Pro Rounded
                        .foregroundColor(.secondaryTaupe) // Use secondary text color
                        .underline()
                }
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    OnboardingIntentionView(
        onIntentionSelected: { intention in print("Selected: \(intention)") },
        onSkip: { print("Skipped") }
    )
} 