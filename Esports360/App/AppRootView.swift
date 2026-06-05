import SwiftUI

// MARK: - AppRootView — Phase-10
// ✔ AppRoute IDs unified to String (was Int — mismatch with API & DeepLinkRouter)
// ✔ .fantasy route added
// ✔ DeepLinkDestination → pushes AppRoute on the active tab’s path (no duplicate modal)
// ✔ fantasyPath added to TabContent
// ✔ DeepLinkRouter.universalURL overload for AppRoute

struct AppRootView: View {

    // ── Shared ViewModels
    @StateObject private var homeVM = HomeViewModel(
        repository: RepositoryFactory.makeMatchRepository()
    )
    @StateObject private var deepLinkRouter = DeepLinkRouter()

    // ── Tab state
    @State private var selectedTab: E360Tab = .home

    // ── Per-tab paths
    @State private var homePath        = NavigationPath()
    @State private var tournamentsPath = NavigationPath()
    @State private var discoverPath    = NavigationPath()
    @State private var saudiHubPath    = NavigationPath()
    @State private var settingsPath    = NavigationPath()
    @State private var fantasyPath     = NavigationPath()

    // ── Onboarding gate
    @AppStorage("app.hasCompletedOnboarding") private var hasCompletedOnboarding = false

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
        // Deep-link: push onto the active tab’s path
        .onChange(of: deepLinkRouter.pendingRoute) { _, route in
            guard let route else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                switch selectedTab {
                case .home:        homePath.append(route)
                case .tournaments: tournamentsPath.append(route)
                case .discover:    discoverPath.append(route)
                case .saudiHub:    saudiHubPath.append(route)
                case .settings:    settingsPath.append(route)
                }
            }
            deepLinkRouter.pendingRoute = nil
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: hasCompletedOnboarding)
    }

    // MARK: - Shell
    private var shell: some View {
        ZStack(alignment: .bottom) {
            E360Color.background.ignoresSafeArea()

            TabContent(
                selectedTab:    selectedTab,
                homeVM:         homeVM,
                homePath:        $homePath,
                tournamentsPath: $tournamentsPath,
                discoverPath:    $discoverPath,
                saudiHubPath:    $saudiHubPath,
                settingsPath:    $settingsPath,
                fantasyPath:     $fantasyPath
            )

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

// MARK: - TabContent
private struct TabContent: View {
    let selectedTab: E360Tab
    let homeVM: HomeViewModel
    @Binding var homePath:        NavigationPath
    @Binding var tournamentsPath: NavigationPath
    @Binding var discoverPath:    NavigationPath
    @Binding var saudiHubPath:    NavigationPath
    @Binding var settingsPath:    NavigationPath
    @Binding var fantasyPath:     NavigationPath

    var body: some View {
        ZStack {
            tab(.home) {
                NavigationStack(path: $homePath) {
                    HomeView(viewModel: homeVM)
                        .navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
                }
            }
            tab(.tournaments) {
                NavigationStack(path: $tournamentsPath) {
                    TournamentCenterView()
                        .navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
                }
            }
            tab(.discover) {
                NavigationStack(path: $discoverPath) {
                    DiscoverView()
                        .navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
                }
            }
            tab(.saudiHub) {
                NavigationStack(path: $saudiHubPath) {
                    SaudiHubView()
                        .navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
                }
            }
            tab(.settings) {
                NavigationStack(path: $settingsPath) {
                    SettingsView()
                        .navigationDestination(for: AppRoute.self) { AppRouteView(route: $0) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func tab(_ tab: E360Tab, @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(selectedTab == tab ? 1 : 0)
            .allowsHitTesting(selectedTab == tab)
    }
}

// MARK: - AppRoute — unified String IDs
enum AppRoute: Hashable {
    case match(id: String)
    case team(id: String)
    case tournament(id: String)
    case player(id: String, gameCode: String? = nil)
}

// MARK: - AppRouteView
private struct AppRouteView: View {
    let route: AppRoute
    var body: some View {
        switch route {
        case .match(let id):
            MatchDetailContainerView(matchID: id)
        case .team(let id):
            UnifiedTeamDetailView(teamId: id)
        case .tournament(let id):
            TournamentDetailView(tournamentId: id)
        case .player(let id, let gameCode):
            PlayerProfileLoaderView(playerId: id, gameCode: gameCode)
        }
    }
}
