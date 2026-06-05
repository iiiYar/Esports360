import SwiftUI

struct SaudiHubView: View {
    @StateObject private var viewModel = SaudiHubViewModel()
    @State private var animateGradient = false

    private let saudiForest = Color(hex: 0x022b18)
    private let saudiNeon   = Color(hex: 0x00a15c)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero

                    // Error Banner
                    if let err = viewModel.errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "wifi.exclamationmark").foregroundStyle(E360Color.gold)
                            Text(err)
                                .font(E360Font.body(12, weight: .semibold))
                                .foregroundStyle(E360Color.textSecondary)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            Button(String(localized: "discover.retry", defaultValue: "إعادة المحاولة")) {
                                Task { await viewModel.load(forceRefresh: true) }
                            }
                            .font(E360Font.body(11, weight: .black))
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(E360Color.primary.opacity(0.82), in: Capsule())
                            .foregroundStyle(E360Color.textPrimary)
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(E360Color.gold.opacity(0.2), lineWidth: 1))
                    }

                    SectionHeader(
                        title: String(localized: "saudiHub.teams", defaultValue: "الفرق السعودية"),
                        systemImage: "flag.and.stars.fill"
                    )

                    if viewModel.isLoading {
                        VStack(spacing: 14) {
                            ForEach(0..<3, id: \.self) { _ in
                                SkeletonRow(height: 130, cornerRadius: 20)
                            }
                        }
                    } else {
                        ForEach(viewModel.teamProfiles) { profile in
                            NavigationLink {
                                UnifiedTeamDetailView(teamId: profile.id)
                            } label: {
                                SaudiTeamCard(profile: profile, saudiNeon: saudiNeon)
                            }
                            .buttonStyle(E360PressScale())
                        }
                    }

                    if let bracket = viewModel.featuredBracket {
                        NavigationLink {
                            TournamentBracketView(tournament: bracket)
                        } label: {
                            TournamentCTA(saudiNeon: saudiNeon)
                        }
                        .buttonStyle(E360PressScale())
                    }
                }
                .padding(18)
            }
            .background(E360Color.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load(forceRefresh: true)
            }
        }
    }

    // MARK: - Hero
    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "tab.saudiHub", defaultValue: "الهوية السعودية"))
                    .font(E360Font.display(30, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(LinearGradient(colors: [E360Color.gold, .white],
                        startPoint: .top, endPoint: .bottom))
                    .shadow(color: E360Color.gold.opacity(0.45), radius: 8)
            }

            Text(String(localized: "saudiHub.ewc", defaultValue: "EWC · كأس العالم للرياضات الإلكترونية"))
                .font(E360Font.body(14, weight: .bold))
                .foregroundStyle(E360Color.gold)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.white.opacity(0.1), in: Capsule())

            Text(String(localized: "saudiHub.description",
                defaultValue: "المقر الرسمي لمتابعة تغطية مواجهات أندية النخبة العالمية والصقور السعودية في كأس العالم للرياضات الإلكترونية"))
                .font(E360Font.body(13, weight: .medium))
                .foregroundStyle(E360Color.textSecondary)
                .lineLimit(2)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background {
            ZStack {
                LinearGradient(
                    colors: [saudiForest, saudiNeon.opacity(animateGradient ? 0.48 : 0.28), E360Color.surface],
                    startPoint: animateGradient ? .topLeading : .bottomLeading,
                    endPoint:   animateGradient ? .bottomTrailing : .topTrailing
                )
                Image(systemName: "flag.fill")
                    .font(.system(size: 140))
                    .foregroundStyle(saudiNeon.opacity(0.06))
                    .offset(x: 100, y: 30)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(colors: [saudiNeon.opacity(0.55), E360Color.gold.opacity(0.42)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
        .shadow(color: saudiNeon.opacity(0.18), radius: 15)
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - SaudiTeamCard
private struct SaudiTeamCard: View {
    let profile: TeamProfile
    let saudiNeon: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                TeamAvatar(team: profile.team, size: 72)
                    .background(E360Color.gold.opacity(0.12), in: Circle())
                    .overlay(Circle().stroke(
                        LinearGradient(colors: [E360Color.gold, saudiNeon],
                            startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2
                    ))
                Text("🇸🇦").font(.system(size: 18)).shadow(radius: 3).offset(x: 6, y: -4)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(profile.team.name)
                    .font(E360Font.display(18, weight: .black))
                    .foregroundStyle(E360Color.textPrimary).lineLimit(1)

                HStack(spacing: 8) {
                    ESImageView(url: profile.displayGameImageURL, fallbackAsset: E360ImageAsset.gamePlaceholder)
                        .frame(width: 18, height: 18)
                    Text(profile.game.shortName)
                        .font(E360Font.mono(11, weight: .bold))
                        .foregroundStyle(profile.game.themeColor)
                    Text("•").foregroundStyle(E360Color.textTertiary)
                    Text(String(format: String(localized: "team.rosterCount"),
                        ArabicNumberFormatter.localized(profile.roster.count)))
                        .font(E360Font.body(11, weight: .semibold))
                }
                .font(E360Font.body(12, weight: .semibold))
                .foregroundStyle(E360Color.textSecondary)

                let winRate = profile.winRateHistory.last?.value ?? 68.0
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(localized: "team.winRate", defaultValue: "معدل الفوز"))
                            .font(E360Font.body(10, weight: .bold)).foregroundStyle(E360Color.textSecondary)
                        Spacer()
                        Text("\(ArabicNumberFormatter.localized(Int(winRate)))%")
                            .font(E360Font.mono(11, weight: .black)).foregroundStyle(E360Color.gold)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(E360Color.elevatedSurface)
                            LinearGradient(colors: [saudiNeon, E360Color.accent],
                                startPoint: .leading, endPoint: .trailing)
                                .frame(width: proxy.size.width * CGFloat(winRate / 100))
                                .clipShape(Capsule())
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10)).foregroundStyle(E360Color.gold)
                                .frame(width: 14, height: 14)
                                .background(E360Color.surface, in: Circle())
                                .overlay(Circle().stroke(E360Color.gold, lineWidth: 1))
                                .offset(x: max(0, proxy.size.width * CGFloat(winRate / 100) - 7))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.top, 4)
            }

            Spacer()
            Image(systemName: "chevron.forward")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(saudiNeon.opacity(0.8))
        }
        .padding(18)
        .e360GlassCard(cornerRadius: 20, borderOpacity: 0.35, shadowRadius: 18, tintColor: saudiNeon)
    }
}

// MARK: - SectionHeader
private struct SectionHeader: View {
    let title: String
    let systemImage: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).font(.system(size: 16, weight: .bold)).foregroundStyle(E360Color.gold)
            Text(title).font(E360Font.display(19, weight: .bold)).foregroundStyle(E360Color.textPrimary)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - TournamentCTA
private struct TournamentCTA: View {
    let saudiNeon: Color
    var body: some View {
        HStack {
            Label(String(localized: "saudiHub.ewc", defaultValue: "EWC · كأس العالم"),
                  systemImage: "trophy.fill")
                .font(E360Font.body(15, weight: .black)).foregroundStyle(E360Color.gold)
            Spacer()
            Text(String(localized: "saudiHub.cta", defaultValue: "استعراض الفروع والترتيب"))
                .font(E360Font.body(12, weight: .bold)).foregroundStyle(.white)
            Image(systemName: "arrow.left.circle.fill")
                .font(.system(size: 16)).foregroundStyle(E360Color.gold)
        }
        .padding(18)
        .background {
            ZStack {
                E360Color.surface
                LinearGradient(colors: [saudiNeon.opacity(0.12), E360Color.gold.opacity(0.06)],
                    startPoint: .leading, endPoint: .trailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(LinearGradient(colors: [E360Color.gold.opacity(0.42), saudiNeon.opacity(0.24)],
                startPoint: .leading, endPoint: .trailing), lineWidth: 1.5))
    }
}

// MARK: - ViewModel
@MainActor
private final class SaudiHubViewModel: ObservableObject {
    #if DEBUG
    @Published private(set) var teamProfiles: [TeamProfile] = [
        MockEsportsData.teamFalconsProfile,
        MockEsportsData.teamProfile(id: MockEsportsData.twistedMinds.id),
        MockEsportsData.teamProfile(id: MockEsportsData.nasr.id)
    ].compactMap(\.self)
    let featuredBracket: TournamentBracket? = MockEsportsData.ewcTournament
    #else
    @Published private(set) var teamProfiles: [TeamProfile] = []
    let featuredBracket: TournamentBracket? = nil
    #endif

    @Published private(set) var isLoading    = false
    @Published private(set) var errorMessage: String?

    private let repository = BackendTeamRepository()

    func load(forceRefresh: Bool = false) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let remote = try await repository.featuredTeams(forceRefresh: forceRefresh)
            if !remote.isEmpty { teamProfiles = remote }
        } catch {
            // Keep seed data visible; show error banner only if we have no data at all
            if teamProfiles.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }
}
