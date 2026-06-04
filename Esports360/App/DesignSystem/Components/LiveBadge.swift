import SwiftUI

struct LiveBadge: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(E360Color.live)
                .frame(width: 7, height: 7)
                .scaleEffect(isPulsing ? 1.45 : 1)
                .opacity(isPulsing ? 0.42 : 1)

            Text("match.live")
                .font(E360Font.mono(11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .background(E360Color.live.opacity(0.28), in: Capsule())
        .overlay(
            Capsule().stroke(E360Color.live.opacity(0.45), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
