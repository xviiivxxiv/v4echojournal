import SwiftUI

struct SoundWaveView: View {
    @State private var animationValues: [CGFloat] = Array(repeating: 0.1, count: 20)
    @State private var timer: Timer?
    
    let isRecording: Bool
    let barColor: Color
    let barWidth: CGFloat
    let barSpacing: CGFloat
    let maxHeight: CGFloat
    
    init(
        isRecording: Bool,
        barColor: Color = .buttonBrown,
        barWidth: CGFloat = 4.6, // Increased by 15% (4 * 1.15)
        barSpacing: CGFloat = 5.75, // Increased by 15% (5 * 1.15)
        maxHeight: CGFloat = 92 // Increased by 15% (80 * 1.15)
    ) {
        self.isRecording = isRecording
        self.barColor = barColor
        self.barWidth = barWidth
        self.barSpacing = barSpacing
        self.maxHeight = maxHeight
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: barSpacing) {
            ForEach(0..<animationValues.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(barColor)
                    .frame(width: barWidth, height: maxHeight * animationValues[index])
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.3...0.8)),
                        value: animationValues[index]
                    )
            }
        }
        .frame(height: maxHeight) // Fixed height to prevent screen jumping
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: isRecording) { _, recording in
            if recording {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        guard isRecording else { return }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateWaveform()
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        
        // Animate bars back to minimum height
        withAnimation(.easeOut(duration: 0.5)) {
            for index in 0..<animationValues.count {
                animationValues[index] = 0.1
            }
        }
    }
    
    private func updateWaveform() {
        for index in 0..<animationValues.count {
            // Create more realistic vocal patterns
            let baseAmplitude = Double.random(in: 0.2...1.0)
            
            // Add some correlation with neighboring bars for smoother wave patterns
            let neighborInfluence: Double
            if index > 0 && index < animationValues.count - 1 {
                let leftNeighbor = Double(animationValues[index - 1])
                let rightNeighbor = Double(animationValues[index + 1])
                neighborInfluence = (leftNeighbor + rightNeighbor) / 4.0
            } else {
                neighborInfluence = 0.1
            }
            
            // Combine base amplitude with neighbor influence for smoother waves
            let finalAmplitude = (baseAmplitude * 0.7) + (neighborInfluence * 0.3)
            
            // Add occasional spikes to simulate speech patterns
            let spike = Double.random(in: 0...1) < 0.1 ? Double.random(in: 0.8...1.0) : 0.0
            
            animationValues[index] = CGFloat(min(1.0, finalAmplitude + spike))
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        Text("Recording Soundwave")
        SoundWaveView(isRecording: true)
        
        Text("Not Recording")
        SoundWaveView(isRecording: false)
    }
    .padding()
    .background(Color.heardGrey)
}




