import SwiftUI

struct TournamentCenterView: View {
    @StateObject private var viewModel = TournamentCenterViewModel()
    @State private var selectedFilter: TournamentStatusFilter = .all
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    metricsStrip

                    if viewModel.featuredTournaments.isEmpty == false {
                        tournamentSection(
                            title: "أبرز البطولات المميزة",
                            subtitle: "بطولات عالمية ومواسم كبرى جاهزة للمتابعة",
                            tournaments: viewModel.featuredTournaments,
                            style: .featured
                        )
                    }

                    if viewModel.majorTournaments.isEmpty == false {
                        tournamentSection(
                            title: "الميجر والبطولات العالمية",
                            subtitle: "شعارات، جوائز، ألعاب، ومعلومات تشغيلية من قاعدة البيانات",
                            tournaments: viewModel.majorTournaments,
                            style: .compact
                        )
                    }

                    allTournamentsSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 96)
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

    private var hero: some View {
        let tournament = viewModel.heroTournament
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                TournamentLogoView(tournament: tournament, viewModel: viewModel, size: 74)

                VStack(alignment: .leading, spacing: 8) {
                    Text("البطولات")
                        .font(E360Font.display(34, weight: .black))
                        .foregroundStyle(E360Color.textPrimary)
                        .lineLimit(1)

                    Text("مركز واحد للميجر، بطولات العالم، EWC، والبطولات النشطة في كل لعبة.")
                        .font(E360Font.body(13, weight: .semibold))
                        .foregroundStyle(E360Color.textSecondary)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }

            if let tournament {
                NavigationLink {
                    TournamentInfoDetailView(tournament: tournament, viewModel: viewModel)
                } label: {
                    FeaturedTournamentHeroCard(tournament: tournament, viewModel: viewModel)
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .padding(20)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        E360Color.primary.opacity(0.30),
                        E360Color.gold.opacity(0.16),
                        E360Color.surface
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "trophy.fill")
                    .font(.system(size: 170, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.035))
                    .offset(x: 115, y: 48)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(E360Color.gold.opacity(0.26), lineWidth: 1)
        )
    }

    private var metricsStrip: some View {
        HStack(spacing: 10) {
            TournamentMetricCard(title: "المميزة", value: viewModel.featuredTournaments.count, color: E360Color.gold)
            TournamentMetricCard(title: "مباشرة", value: viewModel.runningCount, color: E360Color.live)
            TournamentMetricCard(title: "قادمة", value: viewModel.scheduledCount, color: E360Color.accent)
        }
    }

    private func tournamentSection(
        title: String,
        subtitle: String,
        tournaments: [BackendTournamentDTO],
        style: TournamentCardStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: title, subtitle: subtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(tournaments, id: \.id) { tournament in
                        NavigationLink {
                            TournamentInfoDetailView(tournament: tournament, viewModel: viewModel)
                        } label: {
                            TournamentCatalogCard(tournament: tournament, viewModel: viewModel, style: style)
                                .frame(width: style == .featured ? 274 : 236)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var allTournamentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(
                title: "كل البطولات",
                subtitle: "بحث وفرز سريع من قاعدة بيانات Esports360"
            )

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(E360Color.textSecondary)

                TextField("ابحث عن بطولة، لعبة، أو دوري", text: $searchText)
                    .font(E360Font.body(13, weight: .semibold))
                    .foregroundStyle(E360Color.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(E360Color.divider, lineWidth: 1)
            )

            Picker("", selection: $selectedFilter) {
                ForEach(TournamentStatusFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.isLoading && viewModel.tournaments.isEmpty {
                VStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        TournamentSkeletonRow()
                    }
                }
            } else if filteredTournaments.isEmpty {
                EmptyTournamentState()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredTournaments, id: \.id) { tournament in
                        NavigationLink {
                            TournamentInfoDetailView(tournament: tournament, viewModel: viewModel)
                        } label: {
                            TournamentListRow(tournament: tournament, viewModel: viewModel)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
            }
        }
    }

    private var filteredTournaments: [BackendTournamentDTO] {
        viewModel.tournaments
            .filter { selectedFilter.matches($0) }
            .filter { tournament in
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard query.isEmpty == false else { return true }
                let haystack = [
                    tournament.name,
                    tournament.leagueName,
                    tournament.seriesName,
                    tournament.gameName,
                    tournament.gameShortName,
                    tournament.gameSummary,
                    tournament.location,
                    tournament.tier
                ]
                .compactMap(\.self)
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(query)
                return haystack
            }
    }
}

private enum TournamentCardStyle {
    case featured
    case compact
}

private enum TournamentStatusFilter: String, CaseIterable, Identifiable {
    case all
    case running
    case scheduled
    case major

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "الكل"
        case .running: "مباشر"
        case .scheduled: "قادمة"
        case .major: "ميجر"
        }
    }

    func matches(_ tournament: BackendTournamentDTO) -> Bool {
        switch self {
        case .all:
            true
        case .running:
            tournament.status == "running"
        case .scheduled:
            tournament.status == "scheduled"
        case .major:
            tournament.isMajorLike
        }
    }
}

@MainActor
private final class TournamentCenterViewModel: ObservableObject {
    @Published private(set) var tournaments: [BackendTournamentDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let repository = BackendTournamentRepository()

    var heroTournament: BackendTournamentDTO? {
        tournaments.first(where: { $0.slugOrNameContains("esports world cup") })
        ?? featuredTournaments.first
        ?? tournaments.first
    }

    var featuredTournaments: [BackendTournamentDTO] {
        Array(tournaments.filter { $0.isFeatured == true }.prefix(10))
    }

    var majorTournaments: [BackendTournamentDTO] {
        Array(tournaments.filter(\.isMajorLike).prefix(10))
    }

    var runningCount: Int {
        tournaments.filter { $0.status == "running" }.count
    }

    var scheduledCount: Int {
        tournaments.filter { $0.status == "scheduled" }.count
    }

    func load(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            tournaments = try await repository.tournaments(forceRefresh: forceRefresh)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveURL(_ rawValue: String?) -> URL? {
        repository.resolveURL(rawValue)
    }
}

private extension BackendTournamentDTO {
    var displayName: String {
        name ?? leagueName ?? "Tournament"
    }

    var displayGame: String {
        gameShortName ?? gameName ?? gameSummary ?? "Multi-game"
    }

    var displayPrize: String {
        prizePool?.isEmpty == false ? prizePool! : "TBA"
    }

    var displayTier: String {
        tier?
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        ?? "Tournament"
    }

    var isMajorLike: Bool {
        let value = [
            name,
            leagueName,
            tier
        ]
        .compactMap(\.self)
        .joined(separator: " ")
        .lowercased()

        return value.contains("major")
        || value.contains("champion")
        || value.contains("world")
        || value.contains("international")
        || value.contains("tier-s")
    }

    func slugOrNameContains(_ value: String) -> Bool {
        displayName.lowercased().contains(value)
    }
}

private struct FeaturedTournamentHeroCard: View {
    let tournament: BackendTournamentDTO
    let viewModel: TournamentCenterViewModel

    var body: some View {
        HStack(spacing: 14) {
            TournamentLogoView(tournament: tournament, viewModel: viewModel, size: 58)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    TournamentStatusChip(status: tournament.status)
                    Text(tournament.displayTier)
                        .font(E360Font.mono(10, weight: .bold))
                        .foregroundStyle(E360Color.gold)
                        .lineLimit(1)
                }

                Text(tournament.displayName)
                    .font(E360Font.display(18, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
                    .lineLimit(2)

                Text("\(tournament.displayGame) · \(tournament.location ?? "Global")")
                    .font(E360Font.body(12, weight: .semibold))
                    .foregroundStyle(E360Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text("الجوائز")
                    .font(E360Font.body(10, weight: .bold))
                    .foregroundStyle(E360Color.textSecondary)
                Text(tournament.displayPrize)
                    .font(E360Font.number(15, weight: .black))
                    .foregroundStyle(E360Color.gold)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(E360Color.surface.opacity(0.76), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(E360Color.gold.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct TournamentCatalogCard: View {
    let tournament: BackendTournamentDTO
    let viewModel: TournamentCenterViewModel
    let style: TournamentCardStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                TournamentLogoView(tournament: tournament, viewModel: viewModel, size: style == .featured ? 58 : 48)

                Spacer()

                TournamentStatusChip(status: tournament.status)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(tournament.displayName)
                    .font(E360Font.display(style == .featured ? 18 : 16, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: style == .featured ? 48 : 42, alignment: .topLeading)

                Text(tournament.displayGame)
                    .font(E360Font.body(12, weight: .bold))
                    .foregroundStyle(E360Color.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                InfoPill(title: "جائزة", value: tournament.displayPrize, color: E360Color.gold)
                InfoPill(title: "نوع", value: tournament.displayTier, color: E360Color.primary)
            }

            if let dateText = tournament.dateRangeText {
                Label(dateText, systemImage: "calendar")
                    .font(E360Font.body(11, weight: .semibold))
                    .foregroundStyle(E360Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(E360Color.divider, lineWidth: 1)
        )
    }
}

private struct TournamentListRow: View {
    let tournament: BackendTournamentDTO
    let viewModel: TournamentCenterViewModel

    var body: some View {
        HStack(spacing: 14) {
            TournamentLogoView(tournament: tournament, viewModel: viewModel, size: 52)

            VStack(alignment: .leading, spacing: 7) {
                Text(tournament.displayName)
                    .font(E360Font.body(15, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(tournament.displayGame)
                    Text("·")
                    Text(tournament.displayPrize)
                }
                .font(E360Font.body(11, weight: .bold))
                .foregroundStyle(E360Color.textSecondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            TournamentStatusChip(status: tournament.status)
        }
        .padding(14)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(E360Color.divider, lineWidth: 1)
        )
    }
}

private struct TournamentInfoDetailView: View {
    let tournament: BackendTournamentDTO
    let viewModel: TournamentCenterViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 16) {
                    TournamentLogoView(tournament: tournament, viewModel: viewModel, size: 86)

                    VStack(alignment: .leading, spacing: 8) {
                        TournamentStatusChip(status: tournament.status)
                        Text(tournament.displayName)
                            .font(E360Font.display(30, weight: .black))
                            .foregroundStyle(E360Color.textPrimary)
                            .lineLimit(3)

                        Text(tournament.gameSummary ?? tournament.displayGame)
                            .font(E360Font.body(14, weight: .semibold))
                            .foregroundStyle(E360Color.textSecondary)
                    }
                }
                .padding(20)
                .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(E360Color.divider, lineWidth: 1)
                )

                DetailGrid(tournament: tournament)

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "البيانات القادمة", subtitle: "هذه الصفحة جاهزة لإضافة المباريات، الفرق، والـ bracket مباشرة من نفس البطولة.")

                    HStack(spacing: 10) {
                        DetailActionPill(icon: "list.bullet.rectangle", title: "المباريات")
                        DetailActionPill(icon: "chart.xyaxis.line", title: "الترتيب")
                        DetailActionPill(icon: "trophy", title: "القوس")
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 90)
        }
        .background(E360Color.background.ignoresSafeArea())
        .navigationTitle("البطولة")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: DeepLinkRouter.universalURL(for: .tournament(tournament.id))) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}

private struct DetailGrid: View {
    let tournament: BackendTournamentDTO

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            DetailMetric(title: "الجوائز", value: tournament.displayPrize, icon: "dollarsign.circle.fill", color: E360Color.gold)
            DetailMetric(title: "اللعبة", value: tournament.displayGame, icon: "gamecontroller.fill", color: E360Color.accent)
            DetailMetric(title: "النظام", value: tournament.format ?? "TBA", icon: "rectangle.stack.fill", color: E360Color.primary)
            DetailMetric(title: "الموقع", value: tournament.location ?? "Global", icon: "location.fill", color: E360Color.live)
            DetailMetric(title: "المباريات", value: ArabicNumberFormatter.localized(tournament.matchCount ?? 0), icon: "sportscourt.fill", color: E360Color.textSecondary)
            DetailMetric(title: "الفرق", value: ArabicNumberFormatter.localized(tournament.participantCount ?? 0), icon: "person.3.fill", color: E360Color.textSecondary)
        }
    }
}

private struct TournamentLogoView: View {
    let tournament: BackendTournamentDTO?
    let viewModel: TournamentCenterViewModel
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(E360Color.elevatedSurface)

            ESImageView(
                url: viewModel.resolveURL(tournament?.imageUrl),
                fallbackAsset: E360ImageAsset.tournamentPlaceholder,
                fallbackText: tournament?.name
            )
            .padding(size * 0.16)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(E360Color.divider, lineWidth: 1)
        )
    }
}

private struct TournamentStatusChip: View {
    let status: String?

    var body: some View {
        Text(title)
            .font(E360Font.mono(10, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var title: String {
        switch status {
        case "running": "LIVE"
        case "scheduled": "UPCOMING"
        case "completed": "DONE"
        default: "TBA"
        }
    }

    private var color: Color {
        switch status {
        case "running": E360Color.live
        case "scheduled": E360Color.accent
        case "completed": E360Color.textSecondary
        default: E360Color.gold
        }
    }
}

private struct TournamentMetricCard: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(E360Font.body(11, weight: .bold))
                .foregroundStyle(E360Color.textSecondary)
            Text(ArabicNumberFormatter.localized(value))
                .font(E360Font.number(20, weight: .black))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(E360Font.display(20, weight: .black))
                .foregroundStyle(E360Color.textPrimary)

            Text(subtitle)
                .font(E360Font.body(12, weight: .semibold))
                .foregroundStyle(E360Color.textSecondary)
        }
    }
}

private struct InfoPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(E360Font.body(9, weight: .bold))
                .foregroundStyle(E360Color.textSecondary)
            Text(value)
                .font(E360Font.mono(11, weight: .black))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DetailMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(E360Font.body(11, weight: .bold))
                .foregroundStyle(E360Color.textSecondary)
            Text(value)
                .font(E360Font.body(14, weight: .black))
                .foregroundStyle(E360Color.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .padding(14)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(E360Color.divider, lineWidth: 1)
        )
    }
}

private struct DetailActionPill: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(E360Font.body(12, weight: .black))
            .foregroundStyle(E360Color.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(E360Color.divider, lineWidth: 1)
            )
    }
}

private struct TournamentSkeletonRow: View {
    var body: some View {
        HStack(spacing: 14) {
            SkeletonRow(width: 52, height: 52, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 10) {
                SkeletonRow(width: 180, height: 16, cornerRadius: 5)
                SkeletonRow(width: 126, height: 12, cornerRadius: 4)
            }
            Spacer()
            SkeletonRow(width: 74, height: 24, cornerRadius: 12)
        }
        .padding(14)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct EmptyTournamentState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(E360Color.gold)
            Text("لا توجد بطولات مطابقة")
                .font(E360Font.body(14, weight: .black))
                .foregroundStyle(E360Color.textPrimary)
            Text("جرّب فلتر آخر أو امسح البحث الحالي.")
                .font(E360Font.body(12, weight: .semibold))
                .foregroundStyle(E360Color.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 128)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(E360Color.divider, lineWidth: 1)
        )
    }
}

private extension BackendTournamentDTO {
    var dateRangeText: String? {
        guard beginAt != nil || endAt != nil else { return nil }
        let start = beginAt.map { E360DateFormatter.matchDay($0) }
        let end = endAt.map { E360DateFormatter.matchDay($0) }
        switch (start, end) {
        case let (start?, end?):
            return "\(start) - \(end)"
        case let (start?, nil):
            return start
        case let (nil, end?):
            return end
        default:
            return nil
        }
    }
}
