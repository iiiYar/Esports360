import SwiftUI
import Network

// MARK: - MatchDetailViewModel
// ✔ E360StatusBanner replaces private MatchDetailStatusBanner
// ✔ E360SkeletonList(.matchCard) replaces ProgressView skeleton
// ✔ NWPathMonitor + isOffline + clearError()
// ✔ e360RowHighlight on stream buttons
@MainActor
final class MatchDetailViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    @Published private(set) var state:        ViewState = .idle
    @Published private(set) var match:        Match?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isOffline     = false

    private let matchID:    String
    private let repository: MatchRepository
    private let monitor     = NWPathMonitor()
    private let monitorQ    = DispatchQueue(label: "com.esports360.network.match")

    init(matchID: String, initialMatch: Match? = nil) {
        self.matchID    = matchID
        self.match      = initialMatch
        self.repository = RepositoryFactory.makeMatchRepository()
        startNetworkMonitor()
    }

    #if DEBUG
    init(matchID: String, initialMatch: Match?, repository: MatchRepository) {
        self.matchID    = matchID
        self.match      = initialMatch
        self.repository = repository
        startNetworkMonitor()
    }
    #endif

    func load(forceRefresh: Bool = false) async {
        guard state != .loading else { return }
        state = .loading
        do {
            match        = try await repository.match(id: matchID, forceRefresh: forceRefresh)
            errorMessage = nil
            state        = .loaded
        } catch {
            errorMessage = match == nil
                ? String(localized: "match.loadFailed")
                : String(localized: "match.refreshFailed")
            state = .failed(errorMessage ?? "")
        }
    }

    func clearError() { errorMessage = nil }

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                    self?.isOffline = path.status != .satisfied
                }
            }
        }
        monitor.start(queue: monitorQ)
    }

    deinit { monitor.cancel() }
}

// MARK: - MatchDetailContainerView
struct MatchDetailContainerView: View {
    @StateObject private var viewModel: MatchDetailViewModel
    private let matchID: String

    init(match: Match) {
        self.matchID  = match.id
        _viewModel    = StateObject(wrappedValue: MatchDetailViewModel(
            matchID: match.id, initialMatch: match))
    }

    init(matchID: String) {
        self.matchID = matchID
        _viewModel   = StateObject(wrappedValue: MatchDetailViewModel(matchID: matchID))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading where viewModel.match == nil:
                VStack(spacing: 14) {
                    E360SkeletonList(type: .matchCard, count: 3)
                    Spacer()
                }
                .padding(18)
                .background(E360Color.background.ignoresSafeArea())

            case .failed where viewModel.match == nil:
                FeaturePlaceholderView(
                    title: "match.notFound",
                    subtitle: "match.notFoundSubtitle",
                    systemImage: "sportscourt"
                )
                .background(E360Color.background.ignoresSafeArea())

            default:
                if let match = viewModel.match {
                    MatchDetailView(
                        match: match,
                        isRefreshing:   viewModel.state == .loading,
                        errorMessage:   viewModel.errorMessage,
                        isOffline:      viewModel.isOffline,
                        onDismissError: { viewModel.clearError() }
                    )
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.80), value: viewModel.isOffline)
        .animation(.easeOut(duration: 0.22), value: viewModel.errorMessage)
        .task(id: matchID) {
            if viewModel.match == nil        { await viewModel.load() }
            else if viewModel.state == .idle { await viewModel.load(forceRefresh: false) }
        }
        .refreshable { await viewModel.load(forceRefresh: true) }
    }
}

// MARK: - MatchDetailView (pure display)
struct MatchDetailView: View {
    let match:          Match
    var isRefreshing:   Bool   = false
    var errorMessage:   String?
    var isOffline:      Bool   = false
    var onDismissError: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [match.game.themeColor.opacity(0.12), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 220).ignoresSafeArea()

                VStack(spacing: 22) {
                    // Offline banner
                    if isOffline {
                        E360StatusBanner(style: .offline)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Error / refreshing banner
                    if let errorMessage {
                        E360StatusBanner(
                            style: .error(errorMessage),
                            onDismiss: onDismissError
                        )
                        .transition(.opacity)
                    } else if isRefreshing {
                        E360StatusBanner(style: .info(String(localized: "match.refreshing")))
                            .transition(.opacity)
                    }

                    VStack(spacing: 10) {
                        if match.status.isLive { LiveBadge() }

                        Text(match.name)
                            .font(E360Font.display(24, weight: .black))
                            .foregroundStyle(E360Color.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(match.tournament?.name ?? "Tournament")
                            .font(E360Font.body(14, weight: .medium))
                            .foregroundStyle(E360Color.textSecondary)
                    }
                    .padding(.top, 18)

                    HStack(spacing: 14) {
                        detailTeam(match.firstTeam)
                        Text("-")
                            .font(E360Font.number(28, weight: .bold))
                            .foregroundStyle(E360Color.textTertiary)
                        detailTeam(match.secondTeam)
                    }

                    watchStreams
                    mapProgress
                    teamCompositions
                    liveRoundTimeline
                }
                .padding(18)
            }
        }
        .background(E360Color.background.ignoresSafeArea())
        .navigationTitle(match.game.shortName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: DeepLinkRouter.universalURL(for: .match(match.id))) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("action.share"))
            }
        }
    }

    // MARK: - Watch Streams
    private var watchStreams: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("match.watchLive", systemImage: "play.tv.fill")
                    .font(E360Font.display(18, weight: .bold))
                    .foregroundStyle(E360Color.textPrimary)
                Spacer()
                if match.streams.contains(where: \.isLive) || match.status.isLive {
                    LiveBadge()
                }
            }
            if match.streams.isEmpty, let streamURL = match.streamURL {
                streamButton(MatchStream(
                    id: streamURL.absoluteString,
                    title: String(localized: "match.watchLive"),
                    provider: streamURL.host(percentEncoded: false)?.contains("twitch") == true ? "twitch" : "stream",
                    language: nil, url: streamURL, thumbnailURL: nil,
                    viewerCount: nil, isLive: match.status.isLive, isOfficial: true
                ))
            } else if match.streams.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("match.noStreams")
                        .font(E360Font.body(14, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                    Text("match.noStreamsHint")
                        .font(E360Font.body(13, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(E360Color.elevatedSurface,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(match.streams) { stream in streamButton(stream) }
            }
        }
        .padding(16)
        .e360GlassCard(cornerRadius: 16)
    }

    private func streamButton(_ stream: MatchStream) -> some View {
        Button { openURL(stream.openURL) } label: {
            HStack(spacing: 12) {
                ZStack {
                    if let thumbnailURL = stream.thumbnailURL {
                        ESImageView(url: thumbnailURL, fallbackAsset: E360ImageAsset.gamePlaceholder)
                            .frame(width: 54, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(E360Color.elevatedSurface).frame(width: 54, height: 42)
                            .overlay(Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold)).foregroundStyle(E360Color.accent))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(stream.providerDisplayName)
                            .font(E360Font.body(12, weight: .black)).foregroundStyle(E360Color.accent)
                        if stream.isOfficial {
                            Text("match.official")
                                .font(E360Font.body(11, weight: .bold)).foregroundStyle(E360Color.gold)
                        }
                    }
                    Text(stream.title)
                        .font(E360Font.body(14, weight: .bold))
                        .foregroundStyle(E360Color.textPrimary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(E360Color.textSecondary)
            }
            .padding(12)
            .background(E360Color.elevatedSurface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .e360RowHighlight()
        }
        .buttonStyle(.plain)
    }

    private func detailTeam(_ team: Team?) -> some View {
        VStack(spacing: 12) {
            TeamAvatar(team: team, size: 64, game: match.game, isLive: match.status.isLive)
            Text(team?.displayName ?? "TBD")
                .font(E360Font.body(15, weight: .bold)).foregroundStyle(E360Color.textPrimary).lineLimit(1)
            if let team {
                ScorePill(
                    score: ArabicNumberFormatter.localized(match.score(for: team)),
                    isLeading: false
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Map Progress
    private var mapProgress: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("match.mapProgress")
                    .font(E360Font.display(18, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                Spacer()
                Text(matchFormat)
                    .font(E360Font.number(12, weight: .semibold)).foregroundStyle(E360Color.gold)
            }
            if let liveState = match.liveState {
                ProgressView(value: liveState.progress).tint(E360Color.accent)
                HStack(spacing: 12) {
                    MetricPill(title: "match.map",   value: ArabicNumberFormatter.localized(liveState.mapNumber))
                    MetricPill(title: "match.round", value: liveState.roundNumber.map { ArabicNumberFormatter.localized($0) } ?? "--")
                    MetricPill(title: "match.clock", value: liveState.clock ?? "--")
                }
                Text(liveState.phase)
                    .font(E360Font.body(14, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                if !match.maps.isEmpty {
                    MatchMapSeriesView(
                        maps: match.maps, teams: match.teams,
                        currentMapNumber: liveState.mapNumber, game: match.game,
                        showsCS2Scores: match.game == .counterStrike
                    )
                }
            } else {
                ProgressView(
                    value: Double(match.teams.map(match.score(for:)).max() ?? 0),
                    total: Double(max(match.bestOf, 1))
                ).tint(E360Color.accent)
                if match.maps.isEmpty {
                    Text("match.waitingForLiveData")
                        .font(E360Font.body(14, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                } else {
                    MatchMapSeriesView(
                        maps: match.maps, teams: match.teams,
                        currentMapNumber: inferredCurrentMapNumber, game: match.game,
                        showsCS2Scores: match.game == .counterStrike
                    )
                }
            }
        }
        .padding(16).e360GlassCard(cornerRadius: 16)
    }

    // MARK: - Team Compositions
    private var teamCompositions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("match.teamComps")
                .font(E360Font.display(18, weight: .bold)).foregroundStyle(E360Color.textPrimary)
            ForEach(match.teams.prefix(2)) { team in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TeamAvatar(team: team, size: 30, game: match.game, isLive: match.status.isLive)
                        Text(team.displayName)
                            .font(E360Font.body(14, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                    }
                    let picks = match.teamCompositions[team.id] ?? []
                    if picks.isEmpty {
                        Text("match.noCompsYet")
                            .font(E360Font.body(13, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                            ForEach(picks, id: \.self) { pick in
                                Text(pick)
                                    .font(E360Font.body(12, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .background(E360Color.elevatedSurface,
                                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
        .padding(16).e360GlassCard(cornerRadius: 16)
    }

    // MARK: - Live Round Timeline
    private var liveRoundTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("match.roundProgress")
                .font(E360Font.display(18, weight: .bold)).foregroundStyle(E360Color.textPrimary)
            let currentRound = match.liveState?.roundNumber ?? 0
            if currentRound > 0 {
                HStack {
                    Text(String(format: String(localized: "match.roundNumber"),
                                ArabicNumberFormatter.localized(currentRound)))
                        .font(E360Font.body(12, weight: .bold)).foregroundStyle(E360Color.accent)
                    Spacer()
                }
            }
            HStack(spacing: 6) {
                ForEach(1...24, id: \.self) { round in
                    Capsule()
                        .fill(round <= currentRound ? E360Color.accent : E360Color.elevatedSurface)
                        .frame(height: 12)
                }
            }
            Text("match.liveDetailComing")
                .font(E360Font.body(13, weight: .medium)).foregroundStyle(E360Color.textSecondary)
        }
        .padding(16).e360GlassCard(cornerRadius: 16)
    }

    // MARK: - Helpers
    private var matchFormat: String {
        String(format: String(localized: "match.bestOf"),
               ArabicNumberFormatter.localized(match.bestOf))
    }
    private var inferredCurrentMapNumber: Int {
        match.maps.first(where: \.isLive)?.number
            ?? match.maps.first(where: \.isScheduled)?.number
            ?? match.maps.last?.number ?? 1
    }
}

// MARK: - MetricPill
private struct MetricPill: View {
    let title: LocalizedStringKey; let value: String
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(E360Font.body(11, weight: .medium)).foregroundStyle(E360Color.textSecondary).lineLimit(1)
            Text(value)
                .font(E360Font.number(15, weight: .bold)).foregroundStyle(E360Color.textPrimary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(E360Color.elevatedSurface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - MatchMapSeriesView
private struct MatchMapSeriesView: View {
    let maps: [MatchMap]; let teams: [Team]
    let currentMapNumber: Int; let game: EsportsGame; let showsCS2Scores: Bool
    private var sortedMaps: [MatchMap] { maps.sorted { $0.number < $1.number } }

    var body: some View {
        VStack(spacing: showsCS2Scores ? 12 : 10) {
            ForEach(sortedMaps) { map in
                if showsCS2Scores { cs2MapRoundCard(for: map) }
                else              { standardMapRow(for: map)   }
            }
        }
    }

    private func standardMapRow(for map: MatchMap) -> some View {
        HStack(spacing: 12) {
            mapNumberBadge(for: map)
            VStack(alignment: .leading, spacing: 3) {
                Text(mapTitle(for: map))
                    .font(E360Font.body(13, weight: .bold)).foregroundStyle(E360Color.textPrimary).lineLimit(1)
                if let d = durationText(for: map) {
                    Text(d).font(E360Font.mono(11, weight: .semibold)).foregroundStyle(E360Color.textSecondary)
                }
            }
            Spacer()
            statusBadge(for: map)
        }
        .padding(10)
        .background(E360Color.elevatedSurface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(mapBorder(for: map, cornerRadius: 14))
    }

    private func cs2MapRoundCard(for map: MatchMap) -> some View {
        let orderedScores = scoresForDisplay(map)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                mapNumberBadge(for: map)
                VStack(alignment: .leading, spacing: 3) {
                    Text(mapTitle(for: map))
                        .font(E360Font.body(15, weight: .black)).foregroundStyle(E360Color.textPrimary).lineLimit(1)
                    Text(String(format: String(localized: "match.mapNumber"),
                                ArabicNumberFormatter.localized(map.number)))
                        .font(E360Font.body(11, weight: .bold)).foregroundStyle(E360Color.textSecondary)
                }
                Spacer()
                statusBadge(for: map)
            }

            if orderedScores.count >= 2 {
                let first = orderedScores[0]; let second = orderedScores[1]
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        teamRoundScoreBlock(team: team(for: first),  score: first,  isLeading: true)
                        Text(":").font(E360Font.number(22, weight: .black)).foregroundStyle(E360Color.textSecondary)
                        teamRoundScoreBlock(team: team(for: second), score: second, isLeading: false)
                    }
                    if let halves = halvesText(orderedScores) {
                        Text(halves)
                            .font(E360Font.mono(11, weight: .semibold)).foregroundStyle(E360Color.textSecondary)
                            .lineLimit(2).frame(maxWidth: .infinity, alignment: .center)
                    } else if let d = durationText(for: map) {
                        Text(d).font(E360Font.mono(11, weight: .semibold)).foregroundStyle(E360Color.textSecondary)
                    }
                }
                .padding(12)
                .background(E360Color.surface.opacity(0.58),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text("match.cs2RoundScoreUnavailable")
                    .font(E360Font.body(12, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 10)
                    .background(E360Color.surface.opacity(0.58),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(12)
        .background(E360Color.elevatedSurface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(mapBorder(for: map, cornerRadius: 16))
    }

    private func mapNumberBadge(for map: MatchMap) -> some View {
        ZStack {
            Circle().fill(circleFill(for: map)).frame(width: 34, height: 34)
                .overlay(Circle().stroke(circleStroke(for: map),
                                         lineWidth: map.number == currentMapNumber ? 1.5 : 1))
            Text(ArabicNumberFormatter.localized(map.number))
                .font(E360Font.number(13, weight: .black))
                .foregroundStyle(map.number == currentMapNumber ? .white : E360Color.textSecondary)
        }
    }

    private func statusBadge(for map: MatchMap) -> some View {
        Text(statusText(for: map))
            .font(E360Font.body(11, weight: .black)).foregroundStyle(statusColor(for: map))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(statusColor(for: map).opacity(0.12), in: Capsule())
    }

    private func teamRoundScoreBlock(team: Team?, score: MatchMapScore, isLeading: Bool) -> some View {
        let ha: HorizontalAlignment = isLeading ? .leading : .trailing
        let fa: Alignment           = isLeading ? .leading : .trailing
        return VStack(alignment: ha, spacing: 5) {
            Text(team?.displayName ?? "TBD")
                .font(E360Font.body(12, weight: .bold)).foregroundStyle(E360Color.textSecondary).lineLimit(1)
            HStack(spacing: 6) {
                Text(ArabicNumberFormatter.localized(score.totalRounds))
                    .font(E360Font.number(26, weight: .black)).foregroundStyle(E360Color.textPrimary)
                if let side = normalizedSide(score.currentSide) {
                    Text(side)
                        .font(E360Font.mono(10, weight: .black))
                        .foregroundStyle(side == "CT" ? E360Color.accent : E360Color.gold)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background((side == "CT" ? E360Color.accent : E360Color.gold).opacity(0.13), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: fa)
        }
        .frame(maxWidth: .infinity, alignment: fa)
    }

    private func mapBorder(for map: MatchMap, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(map.number == currentMapNumber ? game.themeColor.opacity(0.32) : E360Color.divider,
                    lineWidth: 1)
    }

    private func mapTitle(for map: MatchMap) -> String {
        if let n = map.mapName, !n.isEmpty { return n }
        return String(format: String(localized: "match.mapNumber"),
                      ArabicNumberFormatter.localized(map.number))
    }
    private func statusText(for map: MatchMap) -> String {
        if map.isLive      { return String(localized: "match.live")      }
        if map.isCompleted { return String(localized: "match.finished")  }
        if map.isScheduled { return String(localized: "match.scheduled") }
        return map.status.capitalized
    }
    private func durationText(for map: MatchMap) -> String? {
        guard let s = map.durationSeconds else { return nil }
        return String(format: String(localized: "match.durationMinutes"),
            ArabicNumberFormatter.localized(max(Int((Double(s)/60).rounded()), 1)))
    }
    private func circleFill(for map: MatchMap) -> Color {
        if map.number == currentMapNumber { return game.themeColor }
        if map.isCompleted                { return E360Color.accent.opacity(0.18) }
        return E360Color.surface
    }
    private func circleStroke(for map: MatchMap) -> Color {
        if map.number == currentMapNumber { return game.themeColor.opacity(0.65) }
        if map.isCompleted                { return E360Color.accent.opacity(0.36) }
        return E360Color.divider
    }
    private func statusColor(for map: MatchMap) -> Color {
        if map.isLive      { return E360Color.live    }
        if map.isCompleted { return E360Color.accent  }
        if map.isScheduled { return E360Color.gold    }
        return E360Color.textSecondary
    }
    private func scoresForDisplay(_ map: MatchMap) -> [MatchMapScore] {
        let byID    = Dictionary(uniqueKeysWithValues: map.scores.map { ($0.teamID, $0) })
        let ordered = teams.compactMap { byID[$0.id] }
        return ordered.isEmpty ? map.scores : ordered
    }
    private func team(for score: MatchMapScore) -> Team? {
        teams.first { $0.id == score.teamID }
    }
    private func normalizedSide(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let side = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return side.isEmpty ? nil : side
    }
    private func halvesText(_ vals: [MatchMapScore]) -> String? {
        let v = Array(vals.prefix(2))
        guard v.count == 2 else { return nil }
        var parts: [String] = []
        if let a = v[0].firstHalfRounds,  let b = v[1].firstHalfRounds {
            parts.append(String(format: String(localized: "match.firstHalfShort"),
                "\(ArabicNumberFormatter.localized(a))-\(ArabicNumberFormatter.localized(b))"))
        }
        if let a = v[0].secondHalfRounds, let b = v[1].secondHalfRounds {
            parts.append(String(format: String(localized: "match.secondHalfShort"),
                "\(ArabicNumberFormatter.localized(a))-\(ArabicNumberFormatter.localized(b))"))
        }
        if let a = v[0].overtimeRounds, let b = v[1].overtimeRounds, a > 0 || b > 0 {
            parts.append(String(format: String(localized: "match.overtimeShort"),
                "\(ArabicNumberFormatter.localized(a))-\(ArabicNumberFormatter.localized(b))"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
