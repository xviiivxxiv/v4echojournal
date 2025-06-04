import SwiftUI
import UIKit

struct LightBlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemUltraThinMaterialLight // Or .light, .extraLight

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

#if DEBUG
struct LightBlurView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.red, .blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            Text("Underlying Content")
                .font(.largeTitle)
                .padding()
            
            LightBlurView(style: .systemUltraThinMaterialLight)
                .frame(width: 300, height: 200)
                .cornerRadius(20)
                .overlay(Text("LightBlurView Overlaying Content").foregroundColor(.primary))
        }
    }
}
#endif 