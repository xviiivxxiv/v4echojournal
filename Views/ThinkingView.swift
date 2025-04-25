import SwiftUI

struct ThinkingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                .scaleEffect(1.5)

            Text("Thinking...")
                .font(.title2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.all)) // Adapt background if needed
    }
}

struct ThinkingView_Previews: PreviewProvider {
    static var previews: some View {
        ThinkingView()
    }
} 