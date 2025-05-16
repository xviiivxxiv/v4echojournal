import SwiftUI

struct ChallengesView: View {
    var body: some View {
        // Wrap in NavigationView if it needs its own title,
        // or rely on parent NavigationStack from HomeView.
        // For now, simple text.
        VStack {
            Text("Challenges View")
                .font(.custom("Genty-Regular", size: 24))
                .foregroundColor(Color.primaryEspresso)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundCream)
        // .navigationTitle("Challenges") // Add if HomeView's NavStack handles this
    }
}

#Preview {
    ChallengesView()
} 