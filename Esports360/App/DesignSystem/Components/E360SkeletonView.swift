import SwiftUI

// MARK: - E360SkeletonView
// Structured skeleton loading states for all screen types
// Prevents layout shift by matching real content dimensions exactly
//
// Usage:
//   E360SkeletonView(type: .matchCard)
//   E360SkeletonView(type: .tournamentRow)
//   E360SkeletonView(type: .teamRow)
//   E360SkeletonView(type: .heroCard)

enum E360SkeletonType {
    case matchCard
    case tournamentRow
    case teamRow
    case heroCard
    case profileHeader
    case chipStrip(count: Int)
    case textBlock(lines: Int)
}

struct E360SkeletonView: View {
    let type: E360SkeletonType

    var body: some View {
        Group {
            switch type {
            case .matchCard:      matchCardSkeleton
            case .tournamentRow:  tournamentRowSkeleton
            case .teamRow:        teamRowSkeleton
            case .heroCard:       heroCardSkeleton
            case .profileHeader:  profileHeaderSkeleton
            case .chipStrip(let n): chipStripSkeleton(count: n)
            case .textBlock(let n): textBlockSkeleton(lines: n)
            }
        }
    }

    // MARK: Match Card
    private var matchCardSkeleton: some View {
        HStack(spacing: 14) {
            // Team A
            VStack(spacing: 8) {
                skeletonCircle(size: 44)
                skeletonRect(width: 60, height: 10, radius: 6)
            }
            Spacer()
            // Score center
            VStack(spacing: 6) {
                skeletonRect(width: 72, height: 28, radius: 10)
                skeletonRect(width: 48, height: 8, radius: 6)
            }
            Spacer()
            // Team B
            VStack(spacing: 8) {
                skeletonCircle(size: 44)
                skeletonRect(width: 60, height: 10, radius: 6)
            }
        }
        .padding(16)
        .e360GlassCard(cornerRadius: 18)
    }

    // MARK: Tournament Row
    private var tournamentRowSkeleton: some View {
        HStack(spacing: 12) {
            skeletonRect(width: 40, height: 40, radius: 10)
            VStack(alignment: .leading, spacing: 6) {
                skeletonRect(width: 140, height: 12, radius: 6)
                skeletonRect(width: 90,  height: 9,  radius: 6)
            }
            Spacer()
            skeletonRect(width: 50, height: 22, radius: 11)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Team Row
    private var teamRowSkeleton: some View {
        HStack(spacing: 12) {
            skeletonCircle(size: 44)
            VStack(alignment: .leading, spacing: 6) {
                skeletonRect(width: 100, height: 12, radius: 6)
                skeletonRect(width: 70,  height: 9,  radius: 6)
            }
            Spacer()
            skeletonRect(width: 40, height: 22, radius: 11)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Hero Card
    private var heroCardSkeleton: some View {
        VStack(spacing: 14) {
            skeletonRect(width: nil, height: 180, radius: 20)
            HStack(spacing: 12) {
                skeletonCircle(size: 48)
                VStack(alignment: .leading, spacing: 8) {
                    skeletonRect(width: 120, height: 14, radius: 7)
                    skeletonRect(width: 80,  height: 10, radius: 6)
                }
                Spacer()
            }
        }
    }

    // MARK: Profile Header
    private var profileHeaderSkeleton: some View {
        VStack(spacing: 14) {
            skeletonCircle(size: 80)
            skeletonRect(width: 130, height: 16, radius: 8)
            skeletonRect(width: 90,  height: 12, radius: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: Chip Strip
    private func chipStripSkeleton(count: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                skeletonRect(width: CGFloat(60 + (i % 3) * 20), height: 32, radius: 16)
            }
        }
        .padding(.horizontal, 18)
    }

    // MARK: Text Block
    private func textBlockSkeleton(lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<lines, id: \.self) { i in
                skeletonRect(
                    width: i == lines - 1 ? 140 : nil,
                    height: 11,
                    radius: 6
                )
            }
        }
    }

    // MARK: Atoms
    private func skeletonRect(width: CGFloat?, height: CGFloat, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(E360Color.surface)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .e360Shimmer()
    }
    private func skeletonCircle(size: CGFloat) -> some View {
        Circle()
            .fill(E360Color.surface)
            .frame(width: size, height: size)
            .e360Shimmer()
    }
}

// MARK: - Skeleton List convenience
struct E360SkeletonList: View {
    var type: E360SkeletonType = .matchCard
    var count: Int = 4
    var spacing: CGFloat = 12

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { i in
                E360SkeletonView(type: type)
                    .opacity(1.0 - Double(i) * 0.14)
            }
        }
    }
}
