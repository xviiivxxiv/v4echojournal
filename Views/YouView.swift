import SwiftUI

struct YouView: View {
    var body: some View {
        VStack {
            Text("You View")
                .font(.custom("Genty-Regular", size: 24))
                .foregroundColor(Color.primaryEspresso)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundCream)
        // .navigationTitle("You") // Add if HomeView's NavStack handles this
    }
}

#Preview {
    YouView()
} 