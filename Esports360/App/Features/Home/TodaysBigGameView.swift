import SwiftUI
import OSLog

struct TodaysBigGameView: View {
    let match: Match
    @Binding var isDismissed: Bool
    @State private var animateGradient = false
    @State private var hasReminder = false
    private let notificationService = NotificationService()
    private static let logger = Logger(subsystem: "com.esports360", category: "TodaysBigGameView")

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("home.bigGame", systemImage: "sparkles")
                    .font(E360Font.body(13, weight: .bold))
                    .foregroundStyle(E360Color.gold)

                Spacer()

                HStack(spacing: 12) {
                    if match.status.isLive {
                        LiveBadge()
                    } else if match.status == .upcoming {
                        Button {
                            HapticManager.shared.triggerSelection()
                            Task {
                                if hasReminder {
                                    await notificationService.cancelMatchReminder(match: match)
                                    hasReminder = false
                                } else {
                                    do {
                                        _ = try await notificationService.requestAuthorization()
                                        try await notificationService.scheduleMatchReminder(match: match)
                                        hasReminder = true
                                        HapticManager.shared.triggerNotification(type: .success)
                                    } catch {
                                        Self.logger.error("scheduleMatchReminder failed: \(error, privacy: .public)")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: hasReminder ? "bell.fill" : "bell")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(hasReminder ? E360Color.gold : E360Color.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(.white.opacity(0.06), in: Circle())
                        }
                    }

                    Button {
                        HapticManager.shared.triggerSelection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                            isDismissed = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(E360Color.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.06), in: Circle())
                    }
                }
            }
            .layoutPriority(1)

            HStack(spacing: 14) {
                TeamStack(team: match.firstTeam,  score: match.firstTeam.map  { match.score(for: $0) } ?? 0, isLeading: isLeading(match.firstTeam))
                Text("VS")
                    .font(E360Font.mono(13, weight: .bold)).foregroundStyle(E360Color.textTertiary)
                TeamStack(team: match.secondTeam, score: match.secondTeam.map { match.score(for: $0) } ?? 0, isLeading: isLeading(match.secondTeam))
            }

            HStack(spacing: 8) {
                ESImageView(url: match.displayGameImageURL, fallbackAsset: E360ImageAsset.gamePlaceholder)
                    .frame(width: 18, height: 18)
                Text(match.game.shortName)
                Text(match.tournament?.name ?? "Tournament").lineLimit(1)
                Spacer()
                Text(timeText)
            }
            .font(E360Font.body(12, weight: .medium))
            .foregroundStyle(E360Color.textSecondary)
        }
        .padding(16)
        .background(
            ZStack {
                E360Color.surface
                LinearGradient(
                    colors: [
                        E360Color.primary.opacity(animateGradient ? 0.22 : 0.08),
                        match.game.themeColor.opacity(animateGradient ? 0.08 : 0.22),
                        E360Color.surface
                    ],
                    startPoint: animateGradient ? .topLeading : .bottomLeading,
                    endPoint:   animateGradient ? .bottomTrailing : .topTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LinearGradient(
                    colors: [match.game.themeColor.opacity(0.55), E360Color.primary.opacity(0.24)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
        .shadow(color: match.game.themeColor.opacity(0.18), radius: 24, y: 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
            Task {
                let center = UNUserNotificationCenter.current()
                let requests = await center.pendingNotificationRequests()
                let scheduled = requests.contains { $0.identifier == "match-start-\(match.id)" }
                await MainActor.run { self.hasReminder = scheduled }
            }
        }
    }

    private var timeText: String {
        guard let beginAt = match.beginAt else { return "--" }
        return E360DateFormatter.matchTime(beginAt)
    }

    private func isLeading(_ team: Team?) -> Bool {
        guard let team else { return false }
        let score    = match.score(for: team)
        let maxScore = match.teams.map(match.score(for:)).max() ?? 0
        return score > 0 && score == maxScore
    }
}

private struct TeamStack: View {
    let team: Team?
    let score: Int
    let isLeading: Bool

    var body: some View {
        VStack(spacing: 10) {
            TeamAvatar(team: team, size: 52)
            Text(team?.displayName ?? "TBD")
                .font(E360Font.body(13, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.75)
            ScorePill(score: ArabicNumberFormatter.localized(score), isLeading: isLeading)
        }
        .frame(maxWidth: .infinity)
    }
}
