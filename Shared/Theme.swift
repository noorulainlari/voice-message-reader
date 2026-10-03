import SwiftUI

enum Theme {
    static let accent = Color("AccentColor")
    static let teal = Color(red: 0.05, green: 0.65, blue: 0.58)
    static let deep = Color(red: 0.04, green: 0.36, blue: 0.42)
    static let gradient = LinearGradient(colors: [teal, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// Tiny waveform used as a decorative "loading" animation.
struct WaveformView: View {
    var animating: Bool
    @State private var phase = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                Capsule()
                    .fill(Theme.gradient)
                    .frame(width: 5, height: phase ? CGFloat([18, 34, 24, 40, 22, 30, 16][i]) : CGFloat([30, 14, 36, 16, 38, 14, 28][i]))
            }
        }
        .frame(height: 44)
        .onAppear {
            guard animating else { return }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { phase.toggle() }
        }
    }
}
