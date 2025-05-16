import SwiftUI

struct OnboardingToneView: View {
    // State to track the selected tone
    @State private var selectedTone: String? = nil
    
    // Action to complete onboarding
    var onToneSelected: (String) -> Void
    // Action to skip tone selection (optional, maybe same as selecting a default?)
    var onSkip: () -> Void

    // Example tones - Replace with actual tones and potential icon names (e.g., SF Symbols)
    let tones = [
        ("Supportive", "heart.fill"),
        ("Curious", "questionmark.circle.fill"),
        ("Neutral", "person.fill"),
        ("Direct", "arrow.right.circle.fill")
    ]

    var body: some View {
        ZStack {
            Color.backgroundCream.ignoresSafeArea()

            VStack(alignment: .center, spacing: 20) {
                Spacer()

                Text("How should I respond?")
                    .font(.system(size: 34, weight: .regular, design: .default))
                    .foregroundColor(.primaryEspresso)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 15)
                
                Text("Choose the tone for AI follow-up questions.")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.secondaryTaupe)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
                    .padding(.bottom, 20)

                // Grid or VStack for tone options
                ForEach(tones, id: \.0) { tone, iconName in
                    Button(action: { 
                        withAnimation(.spring()) { // Simple micro-animation
                           selectedTone = tone
                        } 
                        // Add a slight delay before triggering action to allow animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                             onToneSelected(tone)
                        }
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: iconName) // Placeholder icon
                                .font(.system(.title2, design: .rounded))
                            Text(tone)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(selectedTone == tone ? .backgroundCream : .buttonBrown) // Highlight selected
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(selectedTone == tone ? Color.buttonBrown : Color.accentPaleGrey) // Fill selected
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedTone == tone ? Color.clear : Color.buttonBrown, lineWidth: 1.5) // Border if not selected
                        )
                    }
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal, 40)

                Spacer()
                Spacer()

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.secondaryTaupe)
                        .underline()
                }
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    OnboardingToneView(
        onToneSelected: { tone in print("Selected Tone: \(tone)") },
        onSkip: { print("Skipped Tone Selection") }
    )
} 