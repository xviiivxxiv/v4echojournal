import SwiftUI

struct ThinkingAnimationView: View {
    @State private var wave1Offset: CGFloat = -150
    @State private var wave2Offset: CGFloat = -150
    @State private var wave3Offset: CGFloat = -150
    @State private var earScale: CGFloat = 1.0
    @State private var clockRotation: Double = 0.0

    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Ear and Clock Icon
            ZStack {
                Image(systemName: "ear")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.primaryEspresso.opacity(0.8))
                    .scaleEffect(earScale)
                
                Image(systemName: "clock.arrow.circlepath")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 25)
                    .foregroundColor(.primaryEspresso.opacity(0.6))
                    .rotationEffect(.degrees(clockRotation))
            }
            .offset(x: 80)

            // Sound Waves
            Group {
                Capsule()
                    .fill(Color.primaryEspresso.opacity(0.5))
                    .frame(width: 30, height: 60)
                    .offset(x: wave1Offset)
                
                Capsule()
                    .fill(Color.primaryEspresso.opacity(0.4))
                    .frame(width: 25, height: 40)
                    .offset(x: wave2Offset)
                
                Capsule()
                    .fill(Color.primaryEspresso.opacity(0.3))
                    .frame(width: 20, height: 30)
                    .offset(x: wave3Offset)
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 2.0)) {
                wave1Offset = 60
                clockRotation += 45
            }
            withAnimation(.easeInOut(duration: 2.0).delay(0.2)) {
                wave2Offset = 60
            }
            withAnimation(.easeInOut(duration: 2.0).delay(0.4)) {
                wave3Offset = 60
            }

            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                earScale = 1.05
            }
            
            // Reset waves after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                wave1Offset = -150
                wave2Offset = -150
                wave3Offset = -150
            }
        }
        .onAppear {
            // Initial animation trigger
            earScale = 1.05
        }
    }
}

#Preview {
    ThinkingAnimationView()
        .frame(width: 200, height: 100)
        .background(Color.backgroundCream)
}

