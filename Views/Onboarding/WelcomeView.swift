import SwiftUI

struct WelcomeView: View {
    // Action to navigate to the next step (e.g., onboarding or home)
    var onGetStarted: () -> Void

    var body: some View {
        ZStack {
            // Background Color
            Color.backgroundCream
                .ignoresSafeArea()

            VStack(spacing: 20) { // Added spacing for typical vertical arrangement
                Spacer() // Push content towards center

                // Logo - Assuming name "heard_logo" in Assets
                Image("Heard Logo - Full")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200) // Adjust size as needed
                    .padding(.bottom, 10)

                // Tagline
                Text("Because some things need to be heard.")
                    .font(.system(size: 18, weight: .regular, design: .default)) // SF Pro
                    .foregroundColor(.primaryEspresso)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer() // Push content towards center

                // Get Started Button (Pill Style)
                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold, design: .rounded)) // SF Pro Rounded
                        .foregroundColor(.backgroundCream) // Text color on button
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.buttonBrown) // Button background color
                        .clipShape(Capsule()) // Pill shape
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2) // Subtle shadow
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50) // Spacing from bottom edge
            }
        }
    }
}

#Preview {
    WelcomeView(onGetStarted: { print("Get Started tapped!") })
} 