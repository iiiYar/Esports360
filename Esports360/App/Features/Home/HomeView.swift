import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @AppStorage(AppStorageKeys.backendBaseURL) private var backendBaseURL = E360Constants.defaultBackendBaseURL
    @AppStorage(AppStorageKeys.matchRemindersEnabled) private var matchRemindersEnabled = false

    enum HomeTab: String, CaseIterable, Identifiable {
        case live
        case myAlerts
        case allMatches
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .live: "مباشر"
            case .myAlerts: "تنبيهاتي"
            case .allMatches: "المباريات"
            }
        }
    }
    
    @State private var selectedTab: HomeTab = .myAlerts
    @AppStorage("home.bigGameDismissed") private var isBigGameDismissed = false

    // MVP fallback until push/WebSocket delivery is enabled for live match updates.
    private let syncTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    header
                    
                    customSegmentedPicker

                    NewsTickerView(items: viewModel.newsTickerItems)

                    if viewModel.state == .loading && viewModel.lastUpdatedAt == nil {
                        VStack(spacing: 16) {
                            MatchCardSkeletonView()
                            MatchCardSkeletonView()
                            MatchCardSkeletonView()
                        }
                        .padding(.top, 10)
                    } else {
                        // Render Today's Big Game if not dismissed
                        if !isBigGameDismissed, let featured = (viewModel.liveMatches + viewModel.upcomingMatches).first(where: \.isFeaturedSaudiMatch) {
                            TodaysBigGameView(match: featured, isDismissed: $isBigGameDismissed)
                                .transition(.asymmetric(insertion: .opacity, removal: .scale.combined(with: .opacity)))
                        }

                        switch selectedTab {
                        case .live:
                            matchSection(
                                title: "home.liveNow",
                                matches: liveMatchesPrioritized,
                                emptyText: "home.emptyLive"
                            )
                            
                        case .myAlerts:
                            let sections = myAlertsGroupedSections
                            if sections.isEmpty {
                                EmptySectionView(text: "home.emptyAlerts")
                            } else {
                                ForEach(sections) { section in
                                    groupedHeaderView(title: section.dateHeader, subtitle: section.subtitle)
                                        .padding(.top, 8)
                                        
                                    ForEach(section.matches) { match in
                                        NavigationLink {
                                            MatchDetailContainerView(match: match)
                                        } label: {
                                            MatchCardView(match: match)
                                        }
                                        .buttonStyle(PressScaleButtonStyle())
                                    }
                                }
                            }
                            
                        case .allMatches:
                            matchSection(
                                title: "home.liveNow",
                                matches: viewModel.liveMatches,
                                emptyText: "home.emptyLive"
                            )

                            matchSection(
                                title: "home.upNext",
                                matches: viewModel.upcomingMatches,
                                emptyText: "home.emptyUpcoming"
                            )

                            matchSection(
                                title: "home.results",
                                matches: viewModel.completedMatches,
                                emptyText: "home.emptyResults"
                            )
                        }
                    }

                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .padding(.bottom, 96)
            }
            .background(
                ZStack {
                    E360Color.background.ignoresSafeArea()
                    
                    LinearGradient(
                        colors: [E360Color.primary.opacity(0.06), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            )
            .task(id: backendBaseURL) {
                viewModel.updateRepository(baseURL: backendBaseURL)
                await viewModel.load(forceRefresh: false)
                viewModel.startLiveUpdates()
                await viewModel.scheduleLocalMatchReminders(enabled: matchRemindersEnabled)
            }
            .refreshable {
                viewModel.updateRepository(baseURL: backendBaseURL)
                await viewModel.load(forceRefresh: true)
                viewModel.startLiveUpdates()
                await viewModel.scheduleLocalMatchReminders(enabled: matchRemindersEnabled)
            }
            .onChange(of: matchRemindersEnabled) { _, enabled in
                Task {
                    await viewModel.scheduleLocalMatchReminders(enabled: enabled)
                }
            }
            .onReceive(syncTimer) { _ in
                guard viewModel.state != .loading else { return }
                Task {
                    await viewModel.load(forceRefresh: true)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(E360Constants.arabicBrandName)
                    .e360ScreenTitle()

                Text("home.tagline")
                    .font(E360Font.body(15, weight: .medium))
                    .foregroundStyle(E360Color.textSecondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                HeaderIcon(systemName: "bell.badge.fill", color: E360Color.gold)

                switch viewModel.state {
                case .loading:
                    ProgressView()
                        .tint(E360Color.accent)
                        .frame(width: 38, height: 38)
                        .background(E360Color.elevatedSurface, in: Circle())
                case .failed:
                    HeaderIcon(systemName: "exclamationmark.triangle.fill", color: E360Color.gold)
                default:
                    HeaderIcon(systemName: "bolt.fill", color: E360Color.accent)
                }
            }
        }
    }

    private func matchSection(
        title: LocalizedStringKey,
        matches: [Match],
        emptyText: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(E360Font.display(20, weight: .bold))
                .foregroundStyle(E360Color.textPrimary)

            if matches.isEmpty {
                EmptySectionView(text: emptyText)
            } else {
                ForEach(matches) { match in
                    NavigationLink {
                        MatchDetailContainerView(match: match)
                    } label: {
                        MatchCardView(match: match)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Segment Tab Views
    
    private var customSegmentedPicker: some View {
        HStack(spacing: 4) {
            ForEach(HomeTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    HapticManager.shared.triggerSelection()
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        if tab == .live {
                            Circle()
                                .fill(E360Color.live)
                                .frame(width: 5, height: 5)
                                .opacity(viewModel.liveMatches.isEmpty ? 0.35 : 1.0)
                        }
                        Text(tab.displayName)
                            .font(E360Font.body(12, weight: isSelected ? .black : .bold))
                    }
                    .foregroundStyle(isSelected ? E360Color.textPrimary : E360Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(isSelected ? E360Color.primary : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .background(E360Color.surface.opacity(0.48), in: Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.clear,
                            E360Color.accent.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
    }
    
    private func groupedHeaderView(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(E360Font.display(15, weight: .bold))
                .foregroundStyle(E360Color.textSecondary)
            
            Text(subtitle)
                .font(E360Font.body(11, weight: .medium))
                .foregroundStyle(E360Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Personalization Helpers
    
    private var liveMatchesPrioritized: [Match] {
        let favoriteGames = Set(UserDefaults.standard.stringArray(forKey: "user.favoriteGames") ?? [])
        let followedTeams = Set(UserDefaults.standard.stringArray(forKey: "user.followedTeams") ?? [])
        
        return viewModel.liveMatches.sorted { m1, m2 in
            let m1GameFollowed = favoriteGames.contains(m1.game.rawValue)
            let m1TeamFollowed = m1.teams.contains { followedTeams.contains($0.name) }
            let m2GameFollowed = favoriteGames.contains(m2.game.rawValue)
            let m2TeamFollowed = m2.teams.contains { followedTeams.contains($0.name) }
            
            let p1 = (m1GameFollowed ? 2 : 0) + (m1TeamFollowed ? 3 : 0)
            let p2 = (m2GameFollowed ? 2 : 0) + (m2TeamFollowed ? 3 : 0)
            
            if p1 != p2 {
                return p1 > p2
            }
            return (m1.beginAt ?? .distantFuture) < (m2.beginAt ?? .distantFuture)
        }
    }
    
    private var myAlertsMatches: [Match] {
        let favoriteGames = Set(UserDefaults.standard.stringArray(forKey: "user.favoriteGames") ?? [])
        let followedTeams = Set(UserDefaults.standard.stringArray(forKey: "user.followedTeams") ?? [])
        
        let allMatches = viewModel.liveMatches + viewModel.upcomingMatches + viewModel.completedMatches
        
        return allMatches.filter { match in
            favoriteGames.contains(match.game.rawValue) || match.teams.contains { followedTeams.contains($0.name) }
        }
    }
    
    struct GroupedMatchSection: Identifiable {
        let id = UUID()
        let dateHeader: String
        let subtitle: String
        let matches: [Match]
    }
    
    private var myAlertsGroupedSections: [GroupedMatchSection] {
        let matches = myAlertsMatches
        let calendar = Calendar.current
        let dictionary = Dictionary(grouping: matches) { match -> Date in
            let date = match.beginAt ?? Date()
            return calendar.startOfDay(for: date)
        }
        
        let sortedDates = dictionary.keys.sorted()
        
        return sortedDates.map { date -> GroupedMatchSection in
            let sectionMatches = dictionary[date] ?? []
            let headerText = dateHeaderString(for: date)
            
            let count = sectionMatches.count
            let subtitleText: String
            if count == 1 {
                subtitleText = "مباراة واحدة"
            } else if count == 2 {
                subtitleText = "مباراتان"
            } else if count >= 3 && count <= 10 {
                subtitleText = "\(count) مباريات"
            } else {
                subtitleText = "\(count) مباراة"
            }
            
            return GroupedMatchSection(
                dateHeader: headerText,
                subtitle: subtitleText,
                matches: sectionMatches.sorted { ($0.beginAt ?? .distantFuture) < ($1.beginAt ?? .distantFuture) }
            )
        }
    }
    
    private func dateHeaderString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "— اليوم —"
        } else if calendar.isDateInTomorrow(date) {
            return "— غداً —"
        } else if calendar.isDateInYesterday(date) {
            return "— أمس —"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ar")
            formatter.dateFormat = "EEEE، d MMMM"
            let formatted = formatter.string(from: date)
            return "— \(formatted) —"
        }
    }
}

private struct HeaderIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 38, height: 38)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(E360Color.divider, lineWidth: 1))
    }
}
