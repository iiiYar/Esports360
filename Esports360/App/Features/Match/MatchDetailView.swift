import SwiftUI

struct MatchDetailContainerView: View {
    let initialMatch: Match?
    let matchID: String

    @AppStorage(AppStorageKeys.backendBaseURL) private var backendBaseURL = E360Constants.defaultBackendBaseURL
    @State private var match: Match?
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(match: Match) {
        self.initialMatch = match
        self.matchID = match.id
        _match = State(initialValue: match)
    }

    init(matchID: String) {
        self.initialMatch = nil
        self.matchID = matchID
        _match = State(initialValue: nil)
    }

    var body: some View {
        Group {
            if let match {
                MatchDetailView(match: match, isRefreshing: isLoading, errorMessage: errorMessage)
            } else if isLoading {
                ProgressView()
                    .tint(E360Color.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(E360Color.background.ignoresSafeArea())
            } else {
                FeaturePlaceholderView(
                    title: "match.notFound",
                    subtitle: "match.notFoundSubtitle",
                    systemImage: "sportscourt"
                )
                .background(E360Color.background.ignoresSafeArea())
            }
        }
        .task(id: matchID) {
            await load(forceRefresh: true)
        }
        .refreshable {
            await load(forceRefresh: true)
        }
    }

    @MainActor
    private func load(forceRefresh: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let repository = RepositoryFactory.makeMatchRepository(baseURL: backendBaseURL)
            match = try await repository.match(id: matchID, forceRefresh: forceRefresh)
            errorMessage = nil
        } catch {
            if match == nil {
                errorMessage = String(localized: "match.loadFailed")
            } else {
                errorMessage = String(localized: "match.refreshFailed")
            }
        }
    }
}

struct MatchDetailView: View {
    let match: Match
    var isRefreshing = false
    var errorMessage: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                // Subtle ambient header gradient based on game theme color
                LinearGradient(
                    colors: [match.game.themeColor.opacity(0.12), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
                .ignoresSafeArea()

                VStack(spacing: 22) {
                    if let errorMessage {
                        MatchDetailStatusBanner(message: errorMessage, systemImage: "exclamationmark.triangle.fill")
                    } else if isRefreshing {
                        MatchDetailStatusBanner(message: String(localized: "match.refreshing"), systemImage: "arrow.clockwise")
                    }

                    VStack(spacing: 10) {
                        if match.status.isLive {
                            LiveBadge()
                        }

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
                streamButton(
                    MatchStream(
                        id: streamURL.absoluteString,
                        title: String(localized: "match.watchLive"),
                        provider: streamURL.host(percentEncoded: false)?.contains("twitch") == true ? "twitch" : "stream",
                        language: nil,
                        url: streamURL,
                        thumbnailURL: nil,
                        viewerCount: nil,
                        isLive: match.status.isLive,
                        isOfficial: true
                    )
                )
            } else if match.streams.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("match.noStreams")
                        .font(E360Font.body(14, weight: .bold))
                        .foregroundStyle(E360Color.textPrimary)

                    Text("match.noStreamsHint")
                        .font(E360Font.body(13, weight: .medium))
                        .foregroundStyle(E360Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(E360Color.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(match.streams) { stream in
                    streamButton(stream)
                }
            }
        }
        .padding(16)
        .e360GlassCard(cornerRadius: 16)
    }

    private func streamButton(_ stream: MatchStream) -> some View {
        Button {
            openURL(stream.openURL)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if let thumbnailURL = stream.thumbnailURL {
                        ESImageView(url: thumbnailURL, fallbackAsset: E360ImageAsset.gamePlaceholder)
                            .frame(width: 54, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(E360Color.elevatedSurface)
                            .frame(width: 54, height: 42)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(E360Color.accent)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(stream.providerDisplayName)
                            .font(E360Font.body(12, weight: .black))
                            .foregroundStyle(E360Color.accent)

                        if stream.isOfficial {
                            Text("match.official")
                                .font(E360Font.body(11, weight: .bold))
                                .foregroundStyle(E360Color.gold)
                        }
                    }

                    Text(stream.title)
                        .font(E360Font.body(14, weight: .bold))
                        .foregroundStyle(E360Color.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(E360Color.textSecondary)
            }
            .padding(12)
            .background(E360Color.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func detailTeam(_ team: Team?) -> some View {
        VStack(spacing: 12) {
            TeamAvatar(team: team, size: 64, game: match.game, isLive: match.status.isLive)

            Text(team?.displayName ?? "TBD")
                .font(E360Font.body(15, weight: .bold))
                .foregroundStyle(E360Color.textPrimary)
                .lineLimit(1)

            if let team {
                ScorePill(
                    score: ArabicNumberFormatter.localized(match.score(for: team)),
                    isLeading: false
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var mapProgress: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("match.mapProgress")
                    .font(E360Font.display(18, weight: .bold))
                    .foregroundStyle(E360Color.textPrimary)

                Spacer()

                Text(matchFormat)
                    .font(E360Font.number(12, weight: .semibold))
                    .foregroundStyle(E360Color.gold)
            }

            if let liveState = match.liveState {
                ProgressView(value: liveState.progress)
                    .tint(E360Color.accent)

                HStack(spacing: 12) {
                    MetricPill(title: "match.map", value: ArabicNumberFormatter.localized(liveState.mapNumber))
                    MetricPill(title: "match.round", value: liveState.roundNumber.map { ArabicNumberFormatter.localized($0) } ?? "--")
                    MetricPill(title: "match.clock", value: liveState.clock ?? "--")
                }

                Text(liveState.phase)
                    .font(E360Font.body(14, weight: .bold))
                    .foregroundStyle(E360Color.textPrimary)

                if match.maps.isEmpty == false {
                    MatchMapSeriesView(
                        maps: match.maps,
                        teams: match.teams,
                        currentMapNumber: liveState.mapNumber,
                        game: match.game,
                        showsCS2Scores: match.game == .counterStrike
                    )
                }
            } else {
                ProgressView(value: Double(match.teams.map(match.score(for:)).max() ?? 0), total: Double(max(match.bestOf, 1)))
                    .tint(E360Color.accent)

                if match.maps.isEmpty {
                    Text("match.waitingForLiveData")
                        .font(E360Font.body(14, weight: .medium))
                        .foregroundStyle(E360Color.textSecondary)
                } else {
                    MatchMapSeriesView(
                        maps: match.maps,
                        teams: match.teams,
                        currentMapNumber: inferredCurrentMapNumber,
                        game: match.game,
                        showsCS2Scores: match.game == .counterStrike
                    )
                }
            }
        }
        .padding(16)
        .e360GlassCard(cornerRadius: 16)
    }

    private var teamCompositions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("match.teamComps")
                .font(E360Font.display(18, weight: .bold))
                .foregroundStyle(E360Color.textPrimary)

            ForEach(match.teams.prefix(2)) { team in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TeamAvatar(team: team, size: 30, game: match.game, isLive: match.status.isLive)
                        Text(team.displayName)
                            .font(E360Font.body(14, weight: .bold))
                            .foregroundStyle(E360Color.textPrimary)
                    }

                    let picks = match.teamCompositions[team.id] ?? []
                    if picks.isEmpty {
                        Text("match.noCompsYet")
                            .font(E360Font.body(13, weight: .medium))
                            .foregroundStyle(E360Color.textSecondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                            ForEach(picks, id: \.self) { pick in
                                Text(pick)
                                    .font(E360Font.body(12, weight: .bold))
                                    .foregroundStyle(E360Color.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(E360Color.elevatedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .e360GlassCard(cornerRadius: 16)
    }

    private var liveRoundTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("match.roundProgress")
                .font(E360Font.display(18, weight: .bold))
                .foregroundStyle(E360Color.textPrimary)

            let currentRound = match.liveState?.roundNumber ?? 0
            if currentRound > 0 {
                HStack {
                    Text(String(format: String(localized: "match.roundNumber"), ArabicNumberFormatter.localized(currentRound)))
                        .font(E360Font.body(12, weight: .bold))
                        .foregroundStyle(E360Color.accent)
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
                .font(E360Font.body(13, weight: .medium))
                .foregroundStyle(E360Color.textSecondary)
        }
        .padding(16)
        .e360GlassCard(cornerRadius: 16)
    }

    private var matchFormat: String {
        String(format: String(localized: "match.bestOf"), ArabicNumberFormatter.localized(match.bestOf))
    }

    private var inferredCurrentMapNumber: Int {
        match.maps.first(where: \.isLive)?.number
            ?? match.maps.first(where: \.isScheduled)?.number
            ?? match.maps.last?.number
            ?? 1
    }
}

private struct MatchDetailStatusBanner: View {
    let message: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(E360Color.gold)
            Text(message)
                .font(E360Font.body(12, weight: .semibold))
                .foregroundStyle(E360Color.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(E360Color.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(E360Color.gold.opacity(0.32), lineWidth: 1)
        )
    }
}

private struct MetricPill: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(E360Font.body(11, weight: .medium))
                .foregroundStyle(E360Color.textSecondary)
                .lineLimit(1)

            Text(value)
                .font(E360Font.number(15, weight: .bold))
                .foregroundStyle(E360Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(E360Color.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MatchMapSeriesView: View {
    let maps: [MatchMap]
    let teams: [Team]
    let currentMapNumber: Int
    let game: EsportsGame
    let showsCS2Scores: Bool

    private var sortedMaps: [MatchMap] {
        maps.sorted { $0.number < $1.number }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(sortedMaps) { map in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(circleFill(for: map))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(circleStroke(for: map), lineWidth: map.number == currentMapNumber ? 1.5 : 1)
                            )

                        Text(ArabicNumberFormatter.localized(map.number))
                            .font(E360Font.number(13, weight: .black))
                            .foregroundStyle(map.number == currentMapNumber ? .white : E360Color.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(mapTitle(for: map))
                            .font(E360Font.body(13, weight: .bold))
                            .foregroundStyle(E360Color.textPrimary)
                            .lineLimit(1)

                        if showsCS2Scores {
                            cs2ScoreLine(for: map)
                        } else if let durationText = durationText(for: map) {
                            Text(durationText)
                                .font(E360Font.mono(11, weight: .semibold))
                                .foregroundStyle(E360Color.textSecondary)
                        }
                    }

                    Spacer()

                    Text(statusText(for: map))
                        .font(E360Font.body(11, weight: .black))
                        .foregroundStyle(statusColor(for: map))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(statusColor(for: map).opacity(0.12), in: Capsule())
                }
                .padding(10)
                .background(E360Color.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(map.number == currentMapNumber ? game.themeColor.opacity(0.32) : E360Color.divider, lineWidth: 1)
                )
            }
        }
    }

    private func mapTitle(for map: MatchMap) -> String {
        if let mapName = map.mapName, mapName.isEmpty == false {
            return mapName
        }

        return String(
            format: String(localized: "match.mapNumber"),
            ArabicNumberFormatter.localized(map.number)
        )
    }

    private func statusText(for map: MatchMap) -> String {
        if map.isLive { return String(localized: "match.live") }
        if map.isCompleted { return String(localized: "match.finished") }
        if map.isScheduled { return String(localized: "match.scheduled") }
        return map.status.capitalized
    }

    private func durationText(for map: MatchMap) -> String? {
        guard let seconds = map.durationSeconds else { return nil }
        let minutes = max(Int((Double(seconds) / 60.0).rounded()), 1)
        return String(
            format: String(localized: "match.durationMinutes"),
            ArabicNumberFormatter.localized(minutes)
        )
    }

    private func circleFill(for map: MatchMap) -> Color {
        if map.number == currentMapNumber { return game.themeColor }
        if map.isCompleted { return E360Color.accent.opacity(0.18) }
        return E360Color.surface
    }

    private func circleStroke(for map: MatchMap) -> Color {
        if map.number == currentMapNumber { return game.themeColor.opacity(0.65) }
        if map.isCompleted { return E360Color.accent.opacity(0.36) }
        return E360Color.divider
    }

    private func statusColor(for map: MatchMap) -> Color {
        if map.isLive { return E360Color.live }
        if map.isCompleted { return E360Color.accent }
        if map.isScheduled { return E360Color.gold }
        return E360Color.textSecondary
    }

    @ViewBuilder
    private func cs2ScoreLine(for map: MatchMap) -> some View {
        let orderedScores = scoresForDisplay(map)
        if orderedScores.count >= 2 {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(scoreText(orderedScores))
                        .font(E360Font.number(16, weight: .black))
                        .foregroundStyle(E360Color.textPrimary)

                    if let sideText = sideText(orderedScores) {
                        Text(sideText)
                            .font(E360Font.mono(10, weight: .bold))
                            .foregroundStyle(E360Color.gold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(E360Color.gold.opacity(0.12), in: Capsule())
                    }
                }

                if let halvesText = halvesText(orderedScores) {
                    Text(halvesText)
                        .font(E360Font.mono(11, weight: .semibold))
                        .foregroundStyle(E360Color.textSecondary)
                } else if let durationText = durationText(for: map) {
                    Text(durationText)
                        .font(E360Font.mono(11, weight: .semibold))
                        .foregroundStyle(E360Color.textSecondary)
                }
            }
        } else {
            Text("match.cs2RoundScoreUnavailable")
                .font(E360Font.body(11, weight: .medium))
                .foregroundStyle(E360Color.textSecondary)
        }
    }

    private func scoresForDisplay(_ map: MatchMap) -> [MatchMapScore] {
        let byTeamID = Dictionary(uniqueKeysWithValues: map.scores.map { ($0.teamID, $0) })
        let ordered = teams.compactMap { byTeamID[$0.id] }
        return ordered.isEmpty ? map.scores : ordered
    }

    private func scoreText(_ scores: [MatchMapScore]) -> String {
        scores.prefix(2)
            .map { ArabicNumberFormatter.localized($0.totalRounds) }
            .joined(separator: " : ")
    }

    private func sideText(_ scores: [MatchMapScore]) -> String? {
        let sides = scores.prefix(2).compactMap(\.currentSide)
        guard sides.count == 2 else { return nil }
        return sides.joined(separator: " / ")
    }

    private func halvesText(_ scores: [MatchMapScore]) -> String? {
        let values = Array(scores.prefix(2))
        guard values.count == 2 else { return nil }

        var parts: [String] = []
        if let firstA = values[0].firstHalfRounds, let firstB = values[1].firstHalfRounds {
            let score = "\(ArabicNumberFormatter.localized(firstA))-\(ArabicNumberFormatter.localized(firstB))"
            parts.append(String(format: String(localized: "match.firstHalfShort"), score))
        }
        if let secondA = values[0].secondHalfRounds, let secondB = values[1].secondHalfRounds {
            let score = "\(ArabicNumberFormatter.localized(secondA))-\(ArabicNumberFormatter.localized(secondB))"
            parts.append(String(format: String(localized: "match.secondHalfShort"), score))
        }
        if let overtimeA = values[0].overtimeRounds,
           let overtimeB = values[1].overtimeRounds,
           overtimeA > 0 || overtimeB > 0 {
            let score = "\(ArabicNumberFormatter.localized(overtimeA))-\(ArabicNumberFormatter.localized(overtimeB))"
            parts.append(String(format: String(localized: "match.overtimeShort"), score))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
