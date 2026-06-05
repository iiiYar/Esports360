import SwiftUI

struct AppRootView: View {
    @StateObject private var homeViewModel = HomeViewModel(
        repository: RepositoryFactory.makeMatchRepository()
    )
    @StateObject private var deepLinkRouter = DeepLinkRouter()
    @State private var selectedTab: E360Tab = .home
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
                mainContent
            }
        }
        .tint(E360Color.accent)
        .background(E360Color.background.ignoresSafeArea())
        .environmentObject(deepLinkRouter)
        .onOpenURL { deepLinkRouter.open($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) {
            guard let url = $0.webpageURL else { return }
            deepLinkRouter.open(url)
        }
        .sheet(item: $deepLinkRouter.destination) { destination in
            NavigationStack {
                DeepLinkDestinationView(destination: destination)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("navigation.close") { deepLinkRouter.destination = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: hasCompletedOnboarding)
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Background fill
            E360Color.background.ignoresSafeArea()

            // Feature Screens
            Group {
                switch selectedTab {
                case .home:     HomeView(viewModel: homeViewModel)
                case .saudiHub: TournamentCenterView()
                case .discover: DiscoverView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating Tab Bar
            E360TabBar(selectedTab: $selectedTab)
                .padding(.bottom, 10)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - DeepLink Destination
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
