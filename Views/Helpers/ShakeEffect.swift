import SwiftUI

// MARK: - Shake Animation Effect

struct Shake: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

extension View {
    func shake(_ isShaking: Bool) -> some View {
        self.modifier(Shake(animatableData: isShaking ? 1 : 0))
    }
} 