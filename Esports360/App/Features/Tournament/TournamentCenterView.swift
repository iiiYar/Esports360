import SwiftUI
import Network

// MARK: - TournamentCenterView — Phase-4
// ✔ NavigationStack removed — owned by AppRootView shell
// ✔ AppRoute typed navigation via NavigationLink(value:)
// ✔ E360SkeletonView replaces hand-rolled skeletons
// ✔ E360EmptyState replaces EmptyTournamentState
// ✔ E360StatusBanner for offline + error states
// ✔ E360SectionHeader v2 throughout
// ✔ NWPathMonitor in ViewModel for offline detection

struct TournamentCenterView: View {
    @StateObject private var viewModel = TournamentCenterViewModel()
    @State private var selectedFilter: TournamentStatusFilter = .all
    @State private var searchText = ""

    var body: some View {
        ZStack(alignment: .top) {
            E360Color.background.ignoresSafeArea()
            E360AmbientGlow(
                colors: [E360Color.primary.opacity(0.12), E360Color.gold.opacity(0.07), .clear]
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Hero
                    heroSection

                    // ── Offline banner
                    if viewModel.isOffline {
                        E360StatusBanner(style: .offline)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Error banner
                    if let err = viewModel.errorMessage, !viewModel.isLoading {
                        E360StatusBanner(style: .error(err), onDismiss: { viewModel.clearError() })
                            .transition(.opacity)
                    }

                    // ── Metrics strip
                    metricsStrip

                    // ── Featured section
                    if viewModel.isLoading && viewModel.tournaments.isEmpty {
                        tournamentSkeletonSection(
                            title: "tournament.section.featured",
                            subtitle: "tournament.section.featured.sub",
                            style: .featured
                        )
                    } else if !viewModel.featuredTournaments.isEmpty {
                        tournamentSection(
                            title: "tournament.section.featured",
                            subtitle: "tournament.section.featured.sub",
                            tournaments: viewModel.featuredTournaments,
                            style: .featured
                        )
                    }

                    // ── Majors section
                    if viewModel.isLoading && viewModel.tournaments.isEmpty {
                        tournamentSkeletonSection(
                            title: "tournament.section.major",
                            subtitle: "tournament.section.major.sub",
                            style: .compact
                        )
                    } else if !viewModel.majorTournaments.isEmpty {
                        tournamentSection(
                            title: "tournament.section.major",
                            subtitle: "tournament.section.major.sub",
                            tournaments: viewModel.majorTournaments,
                            style: .compact
                        )
                    }

                    // ── All tournaments
                    allTournamentsSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 110)
            }
            .refreshable { await viewModel.load(forceRefresh: true) }
            .animation(.spring(response: 0.32, dampingFraction: 0.80), value: viewModel.isOffline)
            .animation(.easeOut(duration: 0.22), value: viewModel.errorMessage)
        }
        .task { await viewModel.load() }
    }

    // MARK: ─ Hero
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                TournamentLogoView(
                    tournament: viewModel.heroTournament,
                    viewModel: viewModel, size: 74
                )
                VStack(alignment: .leading, spacing: 8) {
                    Text("tab.tournaments", defaultValue: "البطولات")
                        .font(E360Font.display(34, weight: .black))
                        .foregroundStyle(E360Color.textPrimary)
                        .lineLimit(1)
                    Text("tournament.hero.subtitle",
                         defaultValue: "مركز واحد للميجر، بطولات العالم، EWC، والبطولات النشطة في كل لعبة.")
                        .font(E360Font.body(13, weight: .semibold))
                        .foregroundStyle(E360Color.textSecondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }

            if viewModel.isLoading && viewModel.tournaments.isEmpty {
                E360SkeletonView(type: .heroCard)
            } else if let hero = viewModel.heroTournament {
                NavigationLink(value: AppRoute.tournament(id: hero.id)) {
                    FeaturedTournamentHeroCard(tournament: hero, viewModel: viewModel)
                }
                .buttonStyle(E360PressScale())
            }
        }
        .padding(20)
        .background {
            ZStack {
                LinearGradient(
                    colors: [E360Color.primary.opacity(0.30), E360Color.gold.opacity(0.16), E360Color.surface],
                    startPoint: .topLeading, endPoint: .bottomTrailing
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

    // MARK: ─ Metrics Strip
    private var metricsStrip: some View {
        HStack(spacing: 10) {
            TournamentMetricCard(
                title: String(localized: "tournament.metric.featured", defaultValue: "المميزة"),
                value: viewModel.featuredTournaments.count, color: E360Color.gold
            )
            TournamentMetricCard(
                title: String(localized: "tournament.metric.live",     defaultValue: "مباشرة"),
                value: viewModel.runningCount,   color: E360Color.live
            )
            TournamentMetricCard(
                title: String(localized: "tournament.metric.upcoming", defaultValue: "قادمة"),
                value: viewModel.scheduledCount, color: E360Color.accent
            )
        }
    }

    // MARK: ─ Horizontal Section (real data)
    private func tournamentSection(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        tournaments: [BackendTournamentDTO],
        style: TournamentCardStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            E360SectionHeader(
                title: title,
                badge: "\(tournaments.count)",
                badgeColor: style == .featured ? E360Color.gold : E360Color.primary
            )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(tournaments, id: \.id) { t in
                        NavigationLink(value: AppRoute.tournament(id: t.id)) {
                            TournamentCatalogCard(tournament: t, viewModel: viewModel, style: style)
                                .frame(width: style == .featured ? 274 : 236)
                        }
                        .buttonStyle(E360PressScale())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: ─ Horizontal Section (skeletons)
    private func tournamentSkeletonSection(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        style: TournamentCardStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            E360SectionHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { i in
                        TournamentCatalogCardSkeleton(style: style)
                            .frame(width: style == .featured ? 274 : 236)
                            .opacity(1.0 - Double(i) * 0.18)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: ─ All Tournaments
    private var allTournamentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            E360SectionHeader(
                title: "tournament.section.all",
                subtitle: "tournament.section.all.sub",
                icon: "magnifyingglass",
                iconColor: E360Color.accent
            )

            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(E360Color.textSecondary)
                    .font(.system(size: 14, weight: .semibold))
                TextField(
                    String(localized: "tournament.search.placeholder",
                           defaultValue: "ابحث عن بطولة، لعبة، أو دوري"),
                    text: $searchText
                )
                .font(E360Font.body(13, weight: .semibold))
                .foregroundStyle(E360Color.textPrimary)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(E360Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(E360Color.divider, lineWidth: 1))

            // Filter chips using E360ChipGroup pattern (manual for enum)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TournamentStatusFilter.allCases) { filter in
                        let isSel = selectedFilter == filter
                        Button {
                            HapticManager.shared.triggerSelection()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                                selectedFilter = filter
                            }
                        } label: {
                            HStack(spacing: 5) {
                                if filter == .running {
                                    E360LivePulse(color: E360Color.live, size: 5)
                                }
                                Text(filter.title)
                                    .font(E360Font.rounded(12, weight: isSel ? .black : .semibold))
                                    .foregroundStyle(isSel ? filter.color : E360Color.textSecondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                isSel ? filter.color.opacity(0.14) : E360Color.tintedSurface,
                                in: Capsule()
                            )
                            .overlay(Capsule().stroke(
                                isSel ? filter.color.opacity(0.35) : E360Color.divider,
                                lineWidth: 1
                            ))
                        }
                        .buttonStyle(E360PressScale(scale: 0.94))
                        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isSel)
                    }
                }
                .padding(.horizontal, 2)
            }

            // Content
            if viewModel.isLoading && viewModel.tournaments.isEmpty {
                E360SkeletonList(type: .tournamentRow, count: 4)
            } else if filteredTournaments.isEmpty {
                E360EmptyState(
                    style: !searchText.isEmpty
                        ? .noResults(query: searchText)
                        : .noTournaments,
                    onAction: (!searchText.isEmpty || selectedFilter != .all)
                        ? {
                            searchText = ""
                            withAnimation { selectedFilter = .all }
                        }
                        : nil,
                    actionLabel: "عرض كل البطولات"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredTournaments, id: \.id) { t in
                        NavigationLink(value: AppRoute.tournament(id: t.id)) {
                            TournamentListRow(tournament: t, viewModel: viewModel)
                        }
                        .buttonStyle(E360PressScale())
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.22), value: filteredTournaments.count)
        .animation(.easeOut(duration: 0.22), value: viewModel.isLoading)
    }

    // MARK: ─ Filter
    private var filteredTournaments: [BackendTournamentDTO] {
        viewModel.tournaments
            .filter { selectedFilter.matches($0) }
            .filter { t in
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !q.isEmpty else { return true }
                let hay = [t.name, t.leagueName, t.seriesName,
                           t.gameName, t.gameShortName, t.gameSummary,
                           t.location, t.tier]
                    .compactMap(\.self).joined(separator: " ")
                return hay.localizedCaseInsensitiveContains(q)
            }
    }
}

// MARK: - Enums
private enum TournamentCardStyle { case featured, compact }

private enum TournamentStatusFilter: String, CaseIterable, Identifiable {
    case all, running, scheduled, major
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all:       String(localized: "tournament.filter.all",      defaultValue: "الكل")
        case .running:   String(localized: "tournament.filter.live",     defaultValue: "مباشر")
        case .scheduled: String(localized: "tournament.filter.upcoming", defaultValue: "قادمة")
        case .major:     String(localized: "tournament.filter.major",    defaultValue: "ميجر")
        }
    }
    var color: Color {
        switch self {
        case .all:       E360Color.accent
        case .running:   E360Color.live
        case .scheduled: E360Color.primaryBright
        case .major:     E360Color.gold
        }
    }
    func matches(_ t: BackendTournamentDTO) -> Bool {
        switch self {
        case .all:       return true
        case .running:   return t.status == "running"
        case .scheduled: return t.status == "scheduled"
        case .major:     return t.isMajorLike
        }
    }
}

// MARK: - ViewModel
@MainActor
final class TournamentCenterViewModel: ObservableObject {
    @Published private(set) var tournaments:    [BackendTournamentDTO] = []
    @Published private(set) var isLoading      = false
    @Published private(set) var isOffline      = false
    @Published private(set) var errorMessage:  String?

    private let repository   = BackendTournamentRepository()
    private let monitor      = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.esports360.network.tournament")

    // MARK: Computed
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
    var runningCount:   Int { tournaments.filter { $0.status == "running" }.count }
    var scheduledCount: Int { tournaments.filter { $0.status == "scheduled" }.count }

    init() { startNetworkMonitor() }

    // MARK: Public
    func load(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        do {
            tournaments  = try await repository.tournaments(forceRefresh: forceRefresh)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() { errorMessage = nil }

    func resolveURL(_ rawValue: String?) -> URL? {
        repository.resolveURL(rawValue)
    }

    // MARK: Private
    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                    self?.isOffline = path.status != .satisfied
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit { monitor.cancel() }
}

// MARK: - BackendTournamentDTO Helpers
extension BackendTournamentDTO {
    var displayName:  String { name ?? leagueName ?? "Tournament" }
    var displayGame:  String { gameShortName ?? gameName ?? gameSummary ?? "Multi-game" }
    var displayPrize: String { prizePool?.isEmpty == false ? prizePool! : "TBA" }
    var displayTier:  String {
        tier?.replacingOccurrences(of: "-", with: " ").capitalized ?? "Tournament"
    }
    var isMajorLike: Bool {
        let v = [name, leagueName, tier].compactMap(\.self).joined(separator: " ").lowercased()
        return v.contains("major") || v.contains("champion")
            || v.contains("world")  || v.contains("international") || v.contains("tier-s")
    }
    func slugOrNameContains(_ value: String) -> Bool { displayName.lowercased().contains(value) }
    var dateRangeText: String? {
        guard beginAt != nil || endAt != nil else { return nil }
        let start = beginAt.map { E360DateFormatter.matchDay($0) }
        let end   = endAt.map   { E360DateFormatter.matchDay($0) }
        switch (start, end) {
        case let (s?, e?): return "\(s) - \(e)"
        case let (s?, nil): return s
        case let (nil, e?): return e
        default: return nil
        }
    }
}

// MARK: - Sub-Views
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
                        .foregroundStyle(E360Color.gold).lineLimit(1)
                }
                Text(tournament.displayName)
                    .font(E360Font.display(18, weight: .black))
                    .foregroundStyle(E360Color.textPrimary).lineLimit(2)
                Text("\(tournament.displayGame) · \(tournament.location ?? "Global")")
                    .font(E360Font.body(12, weight: .semibold))
                    .foregroundStyle(E360Color.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(localized: "tournament.prize", defaultValue: "الجوائز"))
                    .font(E360Font.body(10, weight: .bold)).foregroundStyle(E360Color.textSecondary)
                Text(tournament.displayPrize)
                    .font(E360Font.number(15, weight: .black)).foregroundStyle(E360Color.gold).lineLimit(1)
            }
        }
        .padding(14)
        .background(E360Color.surface.opacity(0.76),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(E360Color.gold.opacity(0.22), lineWidth: 1))
    }
}

private struct TournamentCatalogCard: View {
    let tournament: BackendTournamentDTO
    let viewModel: TournamentCenterViewModel
    let style: TournamentCardStyle
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                TournamentLogoView(tournament: tournament, viewModel: viewModel,
                                   size: style == .featured ? 58 : 48)
                Spacer()
                TournamentStatusChip(status: tournament.status)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(tournament.displayName)
                    .font(E360Font.display(style == .featured ? 18 : 16, weight: .black))
                    .foregroundStyle(E360Color.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                    .frame(height: style == .featured ? 48 : 42, alignment: .topLeading)
                Text(tournament.displayGame)
                    .font(E360Font.body(12, weight: .bold))
                    .foregroundStyle(E360Color.textSecondary).lineLimit(1)
            }
            HStack(spacing: 8) {
                InfoPill(title: String(localized: "tournament.prize", defaultValue: "جائزة"),
                         value: tournament.displayPrize, color: E360Color.gold)
                InfoPill(title: String(localized: "tournament.tier",  defaultValue: "نوع"),
                         value: tournament.displayTier,  color: E360Color.primary)
            }
            if let dateText = tournament.dateRangeText {
                Label(dateText, systemImage: "calendar")
                    .font(E360Font.body(11, weight: .semibold))
                    .foregroundStyle(E360Color.textSecondary).lineLimit(1)
            }
        }
        .padding(16)
        .background(E360Color.surface,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(E360Color.divider, lineWidth: 1))
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
                    .foregroundStyle(E360Color.textPrimary).lineLimit(2)
                HStack(spacing: 6) {
                    Text(tournament.displayGame)
                    Text("·")
                    Text(tournament.displayPrize)
                }
                .font(E360Font.body(11, weight: .bold))
                .foregroundStyle(E360Color.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            TournamentStatusChip(status: tournament.status)
        }
        .padding(14)
        .background(E360Color.surface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(E360Color.divider, lineWidth: 1))
        .e360RowHighlight()
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
        .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .stroke(E360Color.divider, lineWidth: 1))
    }
}

private struct TournamentStatusChip: View {
    let status: String?
    var body: some View {
        Text(title)
            .font(E360Font.mono(10, weight: .black)).foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
    private var title: String {
        switch status {
        case "running":   "LIVE"
        case "scheduled": "UPCOMING"
        case "completed": "DONE"
        default: "TBA"
        }
    }
    private var color: Color {
        switch status {
        case "running":   E360Color.live
        case "scheduled": E360Color.accent
        case "completed": E360Color.textSecondary
        default: E360Color.gold
        }
    }
}

private struct TournamentMetricCard: View {
    let title: String; let value: Int; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(E360Font.body(11, weight: .bold)).foregroundStyle(E360Color.textSecondary)
            Text(ArabicNumberFormatter.localized(value))
                .font(E360Font.number(20, weight: .black)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(color.opacity(0.18), lineWidth: 1))
    }
}

private struct InfoPill: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(E360Font.body(9, weight: .bold)).foregroundStyle(E360Color.textSecondary)
            Text(value).font(E360Font.mono(11, weight: .black)).foregroundStyle(color).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct TournamentCatalogCardSkeleton: View {
    let style: TournamentCardStyle
    var body: some View {
        E360SkeletonView(type: .heroCard)
            .padding(16)
            .background(E360Color.surface,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(E360Color.divider, lineWidth: 1))
    }
}
