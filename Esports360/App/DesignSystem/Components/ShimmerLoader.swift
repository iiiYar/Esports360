import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    LinearGradient(
                        colors: [
                            .clear,
                            E360Color.primary.opacity(0.06),
                            E360Color.accent.opacity(0.14),
                            E360Color.primary.opacity(0.06),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: width * 2, height: height)
                    .offset(x: -width + (phase * width * 2.5))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

struct SkeletonRow: View {
    var width: CGFloat? = nil
    var height: CGFloat = 20
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(E360Color.elevatedSurface)
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct MatchCardSkeletonView: View {
    var body: some View {
        VStack(spacing: 12) {
            // Header Shimmer
            HStack(spacing: 8) {
                SkeletonRow(width: 60, height: 22, cornerRadius: 11) // Game Chip
                SkeletonRow(width: 120, height: 16, cornerRadius: 4)  // Tournament Name
                Spacer()
                SkeletonRow(width: 45, height: 16, cornerRadius: 4)  // Time
            }
            .padding(.bottom, 6)
            
            // Scoreboard Shimmer
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonRow(width: 32, height: 32, cornerRadius: 16) // Logo
                    SkeletonRow(width: 80, height: 16, cornerRadius: 4)  // Name
                    SkeletonRow(width: 50, height: 42, cornerRadius: 12) // Score
                }
                
                Spacer()
                
                VStack(spacing: 6) {
                    SkeletonRow(width: 15, height: 26, cornerRadius: 4) // colon
                    SkeletonRow(width: 30, height: 12, cornerRadius: 4) // BO info
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    SkeletonRow(width: 32, height: 32, cornerRadius: 16) // Logo
                    SkeletonRow(width: 80, height: 16, cornerRadius: 4)  // Name
                    SkeletonRow(width: 50, height: 42, cornerRadius: 12) // Score
                }
            }
        }
        .padding(14)
        .e360Card(highlighted: false)
    }
}
