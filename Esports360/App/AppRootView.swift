import SwiftUI

// MARK: - AppRootView — Phase-1 Navigation Shell
// Architecture:
//   TabView → per-tab NavigationStack (each stack independent)
//   Each NavigationStack carries its own @State path
//   Pop-to-root when user taps the already-selected tab
//   Onboarding gate preserved as before

struct AppRootView: View {

    // MARK: — Shared ViewModels (survive tab switches)
    @StateObject private var homeVM = HomeViewModel(
        repository: RepositoryFactory.makeMatchRepository()
    )
    @StateObject private var deepLinkRouter = DeepLinkRouter()

    // MARK: — Navigation state
    @State private var selectedTab: E360Tab = .home

    // Per-tab NavigationPaths — keep state across tab switches
    @State private var homePath        = NavigationPath()
    @State private var tournamentsPath = NavigationPath()
    @State private var discoverPath    = NavigationPath()
    @State private var saudiHubPath    = NavigationPath()
    @State private var settingsPath    = NavigationPath()

    // MARK: — Gate
    @AppStorage("app.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // MARK: — Body
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            } else {
                shell
            }
        }
        .tint(E360Color.accent)
        .background(E360Color.background.ignoresSafeArea())
        .environmentObject(deepLinkRouter)
        .onOpenURL { deepLinkRouter.open($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) {
            if let url = $0.webpageURL { deepLinkRouter.open(url) }
        }
        // Deep-link modal
        .sheet(item: $deepLinkRouter.destination) { destination in
            NavigationStack {
                DeepLinkDestinationView(destination: destination)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("navigation.close") {
                                deepLinkRouter.destination = nil
                            }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: hasCompletedOnboarding)
    }

    // MARK: — Main shell
    private var shell: some View {
        ZStack(alignment: .bottom) {
            E360Color.background.ignoresSafeArea()

            // ── Per-tab NavigationStacks ──────────────────────────────────
            TabContent(selectedTab: selectedTab,
                       homeVM: homeVM,
                       homePath: $homePath,
                       tournamentsPath: $tournamentsPath,
                       discoverPath: $discoverPath,
                       saudiHubPath: $saudiHubPath,
                       settingsPath: $settingsPath)

            // ── Floating Tab Bar ──────────────────────────────────────────
            E360TabBar(
                selectedTab: $selectedTab,
                onSameTabTap: { tab in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                        switch tab {
                        case .home:        homePath        = NavigationPath()
                        case .tournaments: tournamentsPath = NavigationPath()
                        case .discover:    discoverPath    = NavigationPath()
                        case .saudiHub:    saudiHubPath    = NavigationPath()
                        case .settings:    settingsPath    = NavigationPath()
                        }
                    }
                }
            )
            .padding(.bottom, 10)
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - TabContent — renders only the active stack (performance)
private struct TabContent: View {
    let selectedTab: E360Tab
    let homeVM: HomeViewModel
    @Binding var homePath:        NavigationPath
    @Binding var tournamentsPath: NavigationPath
    @Binding var discoverPath:    NavigationPath
    @Binding var saudiHubPath:    NavigationPath
    @Binding var settingsPath:    NavigationPath

    var body: some View {
        ZStack {
            // Home
            NavigationStack(path: $homePath) {
                HomeView(viewModel: homeVM)
                    .navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
            }
            .opacity(selectedTab == .home ? 1 : 0)
            .allowsHitTesting(selectedTab == .home)

            // Tournaments
            NavigationStack(path: $tournamentsPath) {
                TournamentCenterView()
                    .navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
            }
            .opacity(selectedTab == .tournaments ? 1 : 0)
            .allowsHitTesting(selectedTab == .tournaments)

            // Discover
            NavigationStack(path: $discoverPath) {
                DiscoverView()
                    .navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
            }
            .opacity(selectedTab == .discover ? 1 : 0)
            .allowsHitTesting(selectedTab == .discover)

            // Saudi Hub
            NavigationStack(path: $saudiHubPath) {
                SaudiHubView()
                    .navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
            }
            .opacity(selectedTab == .saudiHub ? 1 : 0)
            .allowsHitTesting(selectedTab == .saudiHub)

            // Settings
            NavigationStack(path: $settingsPath) {
                SettingsView()
                    .navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
            }
            .opacity(selectedTab == .settings ? 1 : 0)
            .allowsHitTesting(selectedTab == .settings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AppRoute — typed navigation destination
enum AppRoute: Hashable {
    case match(id: Int)
    case team(id: Int)
    case tournament(id: Int)
    case player(id: Int, gameCode: String?)
}

// MARK: - AppRouteView
private struct AppRouteView: View {
    let route: AppRoute
    var body: some View {
        switch route {
        case .match(let id):                    MatchDetailContainerView(matchID: id)
        case .team(let id):                     UnifiedTeamDetailView(teamId: id)
        case .tournament(let id):               TournamentDetailView(tournamentId: id)
        case .player(let id, let gameCode):     PlayerProfileLoaderView(playerId: id, gameCode: gameCode)
        }
    }
}

// MARK: - DeepLink Destination (modal)
private struct DeepLinkDestinationView: View {
    let destination: DeepLinkDestination
    var body: some View {
        switch destination {
        case .match(let id):      MatchDetailContainerView(matchID: id)
        case .team(let id):       UnifiedTeamDetailView(teamId: id)
        case .tournament(let id): TournamentDetailView(tournamentId: id)
        case .player(let id):     PlayerProfileLoaderView(playerId: id, gameCode: nil)
        }
    }
}
