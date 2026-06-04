import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @AppStorage(AppStorageKeys.backendBaseURL)       private var backendBaseURL        = E360Constants.defaultBackendBaseURL
    @AppStorage(AppStorageKeys.matchRemindersEnabled) private var matchRemindersEnabled = false
    @AppStorage("home.bigGameDismissed")             private var isBigGameDismissed    = false
    @State private var selectedTab: HomeTab = .myAlerts

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    header
                    customSegmentedPicker
                    NewsTickerView(items: viewModel.newsTickerItems)

                    if viewModel.state == .loading && viewModel.lastUpdatedAt == nil {
                        skeletonStack
                    } else {
                        bigGameBanner
                        tabContent
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .padding(.bottom, 96)
            }
            .background {
                ZStack {
                    E360Color.background.ignoresSafeArea()
                    LinearGradient(colors: [E360Color.primary.opacity(0.06), .clear],
                        startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                }
            }
            .task(id: backendBaseURL) {
                viewModel.updateRepository(baseURL: backendBaseURL)
                await viewModel.load(forceRefresh: false)
                viewModel.startLiveUpdates()
                viewModel.startPolling()
                await viewModel.scheduleLocalMatchReminders(enabled: matchRemindersEnabled)
            }
            .refreshable {
                viewModel.updateRepository(baseURL: backendBaseURL)
                await viewModel.load(forceRefresh: true)
                viewModel.startLiveUpdates()
                await viewModel.scheduleLocalMatchReminders(enabled: matchRemindersEnabled)
            }
            .onChange(of: matchRemindersEnabled) { _, enabled in
                Task { await viewModel.scheduleLocalMatchReminders(enabled: enabled) }
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(E360Constants.arabicBrandName).e360ScreenTitle()
                Text("home.tagline")
                    .font(E360Font.body(15, weight: .medium))
                    .foregroundStyle(E360Color.textSecondary)
            }
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                HeaderIcon(systemName: "bell.badge.fill", color: E360Color.gold)
                switch viewModel.state {
                case .loading:
                    ProgressView().tint(E360Color.accent)
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

    // MARK: - Skeleton
    @ViewBuilder
    private var skeletonStack: some View {
        VStack(spacing: 16) {
            MatchCardSkeletonView()
            MatchCardSkeletonView()
            MatchCardSkeletonView()
        }
        .padding(.top, 10)
    }

    // MARK: - Big Game Banner
    @ViewBuilder
    private var bigGameBanner: some View {
        if !isBigGameDismissed,
           let featured = (viewModel.liveMatches + viewModel.upcomingMatches)
               .first(where: \.isFeaturedSaudiMatch) {
            TodaysBigGameView(match: featured, isDismissed: $isBigGameDismissed)
                .transition(.asymmetric(insertion: .opacity, removal: .scale.combined(with: .opacity)))
        }
    }

    // MARK: - Tab Content
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .live:
            matchSection(
                title: String(localized: "home.liveNow",    defaultValue: "مباشر الآن"),
                matches: viewModel.liveMatchesPrioritized,
                emptyKey: "home.emptyLive"
            )
        case .myAlerts:
            let sections = viewModel.myAlertsGroupedSections
            if sections.isEmpty {
                EmptySectionView(text: "home.emptyAlerts")
            } else {
                ForEach(sections) { section in
                    groupedHeaderView(title: section.dateHeader, subtitle: section.subtitle)
                        .padding(.top, 8)
                    ForEach(section.matches) { match in
                        NavigationLink { MatchDetailContainerView(match: match) } label: {
                            MatchCardView(match: match)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
            }
        case .allMatches:
            matchSection(title: String(localized: "home.liveNow",   defaultValue: "مباشر الآن"),  matches: viewModel.liveMatches,      emptyKey: "home.emptyLive")
            matchSection(title: String(localized: "home.upNext",    defaultValue: "القادمة"),     matches: viewModel.upcomingMatches,  emptyKey: "home.emptyUpcoming")
            matchSection(title: String(localized: "home.results",   defaultValue: "النتائج"),     matches: viewModel.completedMatches, emptyKey: "home.emptyResults")
        }
    }

    // MARK: - Segmented Picker
    private var customSegmentedPicker: some View {
        HStack(spacing: 4) {
            ForEach(HomeTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    HapticManager.shared.triggerSelection()
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 6) {
                        if tab == .live {
                            Circle().fill(E360Color.live).frame(width: 5, height: 5)
                                .opacity(viewModel.liveMatches.isEmpty ? 0.35 : 1.0)
                        }
                        Text(tab.displayName)
                            .font(E360Font.body(12, weight: isSelected ? .black : .bold))
                    }
                    .foregroundStyle(isSelected ? E360Color.textPrimary : E360Color.textSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background(Capsule().fill(isSelected ? E360Color.primary : .clear))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .background(E360Color.surface.opacity(0.48), in: Capsule())
        .overlay(
            Capsule().stroke(
                LinearGradient(colors: [Color.white.opacity(0.14), .clear, E360Color.accent.opacity(0.24)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2
            )
        )
    }

    // MARK: - Helpers
    private func matchSection(title: String, matches: [Match], emptyKey: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(E360Font.display(20, weight: .bold)).foregroundStyle(E360Color.textPrimary)
            if matches.isEmpty {
                EmptySectionView(text: emptyKey)
            } else {
                ForEach(matches) { match in
                    NavigationLink { MatchDetailContainerView(match: match) } label: {
                        MatchCardView(match: match)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }

    private func groupedHeaderView(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(E360Font.display(15, weight: .bold)).foregroundStyle(E360Color.textSecondary)
            Text(subtitle).font(E360Font.body(11, weight: .medium)).foregroundStyle(E360Color.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
    }
}

// MARK: - HomeTab
enum HomeTab: String, CaseIterable, Identifiable {
    case live, myAlerts, allMatches
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .live:       String(localized: "home.tab.live",       defaultValue: "مباشر")
        case .myAlerts:   String(localized: "home.tab.myAlerts",   defaultValue: "تنبيهاتي")
        case .allMatches: String(localized: "home.tab.allMatches", defaultValue: "المباريات")
        }
    }
}

// MARK: - HeaderIcon
private struct HeaderIcon: View {
    let systemName: String; let color: Color
    var body: some View {
        Image(systemName: systemName).font(.system(size: 15, weight: .bold)).foregroundStyle(color)
            .frame(width: 38, height: 38)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(E360Color.divider, lineWidth: 1))
    }
}
