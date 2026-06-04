import Foundation
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
                ZStack(alignment: .bottom) {
                    Group {
                        switch selectedTab {
                        case .home:
                            HomeView(viewModel: homeViewModel)
                        case .saudiHub:
                            TournamentCenterView()
                        case .discover:
                            DiscoverView()
                        case .settings:
                            SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    E360TabBar(selectedTab: $selectedTab)
                        .padding(.bottom, 16)
                }
            }
        }
        .tint(E360Color.accent)
        .background(E360Color.background.ignoresSafeArea())
        .environmentObject(deepLinkRouter)
        .onOpenURL { url in
            deepLinkRouter.open(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            deepLinkRouter.open(url)
        }
        .sheet(item: $deepLinkRouter.destination) { destination in
            DeepLinkDestinationView(destination: destination)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.76), value: hasCompletedOnboarding)
    }
}

private struct DeepLinkDestinationView: View {
    let destination: DeepLinkDestination
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            destinationView
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("navigation.close") {
                            dismiss()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case .match(let id):
            MatchDetailContainerView(matchID: id)
        case .team(let id):
            UnifiedTeamDetailView(teamId: id)
        case .tournament(let id):
            TournamentDetailView(tournamentId: id)

        case .player(let id):
            PlayerProfileLoaderView(playerId: id, gameCode: nil)
        }
    }
}

private struct DeepLinkNotFoundView: View {
    var body: some View {
        FeaturePlaceholderView(
            title: "deepLink.notFound",
            subtitle: "deepLink.notFoundSubtitle",
            systemImage: "link.badge.plus"
        )
        .background(E360Color.background.ignoresSafeArea())
    }
}
