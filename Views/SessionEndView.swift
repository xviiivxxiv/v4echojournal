import SwiftUI

struct SessionEndView: View {
    
    // Action to dismiss the view (likely back to Home or History)
    var onDismiss: () -> Void
    
    // Optional: Pass in the affirmation message if it's dynamic
    let affirmationMessage: String = "Taking time to reflect is a gift to yourself."

    var body: some View {
        ZStack {
            Color.backgroundCream.ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                Text("You've been heard.")
                    .font(.custom("Genty", size: 36))
                    .foregroundColor(.primaryEspresso)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(affirmationMessage)
                    .font(.custom("Very Vogue", size: 18))
                    .foregroundColor(.secondaryTaupe)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
                Spacer()

                Button("Save & Close") {
                    // Perform any final save actions if needed before dismissing
                    onDismiss()
                }
                .buttonStyle(PillButtonStyle()) // Reuse the pill button style
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 50) // Ensure button is spaced from bottom
        }
        // Hide nav bar if presented in a way that might show one
        .navigationBarHidden(true)
    }
}

#Preview {
    SessionEndView(onDismiss: { print("Dismiss Session End") })
} 