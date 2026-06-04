import SwiftUI

struct TournamentDetailView: View {
    let tournamentId: String

    @StateObject private var viewModel = TournamentDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 14) {
                    SkeletonRow(height: 210, cornerRadius: 24)
                    SkeletonRow(height: 96, cornerRadius: 18)
                    SkeletonRow(height: 160, cornerRadius: 18)
                    Spacer()
                }
                .padding(18)
            } else if let tournament = viewModel.tournament {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        TournamentDetailHero(tournament: tournament)
                        TournamentDetailStats(tournament: tournament)
                        TournamentDetailInfo(tournament: tournament)
                    }
                    .padding(18)
                    .padding(.bottom, 60)
                }
                .refreshable {
                    await viewModel.load(id: tournamentId, forceRefresh: true)
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(E360Color.gold)

                    Text(viewModel.errorMessage ?? String(localized: "discover.error.loading", defaultValue: "حدث خطأ أثناء تحميل البيانات"))
                        .font(E360Font.body(14, weight: .bold))
                        .foregroundStyle(E360Color.textSecondary)
                        .multilineTextAlignment(.center)

                    Button(String(localized: "discover.retry", defaultValue: "إعادة المحاولة")) {
                        Task { await viewModel.load(id: tournamentId, forceRefresh: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(E360Color.primary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(E360Color.background.ignoresSafeArea())
        .navigationTitle(viewModel.tournament?.name ?? String(localized: "tournament.details", defaultValue: "البطولة"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: tournamentId) {
            await viewModel.load(id: tournamentId)
        }
    }
}

@MainActor
private final class TournamentDetailViewModel: ObservableObject {
    @Published private(set) var tournament: BackendTournamentDTO?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let apiClient = RepositoryFactory.makeAPIClient()

    func load(id: String, forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            tournament = try await apiClient.tournament(id: id, forceRefresh: forceRefresh)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TournamentDetailHero: View {
    let tournament: BackendTournamentDTO

    var body: some View {
        let game = EsportsGame(backendCode: tournament.gameCode)
        let themeColor = game.themeColor

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ESImageView(
                    url: BackendURLResolver.resolveBackendURL(tournament.imageUrl),
                    fallbackAsset: E360ImageAsset.tournamentPlaceholder,
                    fallbackText: tournament.name
                )
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(themeColor.opacity(0.35), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    TournamentDetailStatusBadge(status: tournament.status)

                    Text(tournament.name ?? tournament.leagueName ?? "Tournament")
                        .font(E360Font.display(24, weight: .black))
                        .foregroundStyle(E360Color.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 7) {
                        ESImageView(
                            url: BackendURLResolver.resolveBackendURL(tournament.gameImageUrl),
                            fallbackAsset: E360ImageAsset.gamePlaceholder
                        )
                        .frame(width: 18, height: 18)

                        Text(tournament.gameShortName ?? tournament.gameName ?? game.shortName)
                            .font(E360Font.mono(11, weight: .black))
                            .foregroundStyle(themeColor)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(themeColor.opacity(0.12), in: Capsule())
                }

                Spacer(minLength: 0)
            }

            if let summary = tournament.gameSummary ?? tournament.leagueName {
                Text(summary)
                    .font(E360Font.body(13, weight: .medium))
                    .foregroundStyle(E360Color.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(18)
        .background {
            ZStack {
                E360Color.surface
                LinearGradient(
                    colors: [themeColor.opacity(0.14), E360Color.gold.opacity(0.05), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(themeColor.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct TournamentDetailStats: View {
    let tournament: BackendTournamentDTO

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            TournamentDetailMetric(
                title: String(localized: "tournament.prize", defaultValue: "الجوائز"),
                value: tournament.prizePool?.isEmpty == false ? tournament.prizePool! : "TBA",
                icon: "dollarsign.circle.fill",
                color: E360Color.gold
            )

            TournamentDetailMetric(
                title: String(localized: "tournament.matches", defaultValue: "المباريات"),
                value: ArabicNumberFormatter.localized(tournament.matchCount ?? 0),
                icon: "sportscourt.fill",
                color: E360Color.accent
            )

            TournamentDetailMetric(
                title: String(localized: "tournament.teams", defaultValue: "الفرق"),
                value: ArabicNumberFormatter.localized(tournament.participantCount ?? 0),
                icon: "person.3.fill",
                color: E360Color.primary
            )

            TournamentDetailMetric(
                title: String(localized: "tournament.tier", defaultValue: "المستوى"),
                value: tournament.tier?.replacingOccurrences(of: "-", with: " ").capitalized ?? "TBA",
                icon: "star.fill",
                color: E360Color.live
            )
        }
    }
}

private struct TournamentDetailInfo: View {
    let tournament: BackendTournamentDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TournamentDetailInfoRow(title: String(localized: "tournament.format", defaultValue: "النظام"), value: tournament.format ?? "TBA")
            TournamentDetailInfoRow(title: String(localized: "tournament.location", defaultValue: "الموقع"), value: tournament.location ?? "TBA")

            if let start = tournament.beginAt {
                TournamentDetailInfoRow(title: String(localized: "tournament.starts", defaultValue: "البداية"), value: E360DateFormatter.matchDay(start))
            }

            if let end = tournament.endAt {
                TournamentDetailInfoRow(title: String(localized: "tournament.ends", defaultValue: "النهاية"), value: E360DateFormatter.matchDay(end))
            }

            if let prizeNote = tournament.prizeNote, prizeNote.isEmpty == false {
                TournamentDetailInfoRow(title: String(localized: "tournament.note", defaultValue: "ملاحظة"), value: prizeNote)
            }
        }
        .padding(16)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(E360Color.divider, lineWidth: 1)
        )
    }
}

private struct TournamentDetailMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(E360Font.number(17, weight: .black))
                .foregroundStyle(E360Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(E360Font.body(10, weight: .bold))
                .foregroundStyle(E360Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct TournamentDetailInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(E360Font.body(12, weight: .bold))
                .foregroundStyle(E360Color.textSecondary)

            Spacer(minLength: 12)

            Text(value)
                .font(E360Font.body(13, weight: .semibold))
                .foregroundStyle(E360Color.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct TournamentDetailStatusBadge: View {
    let status: String?

    var body: some View {
        let text: String = switch status {
        case "running": String(localized: "match.live", defaultValue: "مباشر الآن")
        case "scheduled": String(localized: "match.upcoming", defaultValue: "قادمة")
        case "completed": String(localized: "match.completed", defaultValue: "منتهية")
        default: status?.uppercased() ?? "TBA"
        }

        let color: Color = switch status {
        case "running": E360Color.live
        case "scheduled": E360Color.accent
        case "completed": E360Color.textSecondary
        default: E360Color.primary
        }

        Text(text)
            .font(E360Font.body(10, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}
