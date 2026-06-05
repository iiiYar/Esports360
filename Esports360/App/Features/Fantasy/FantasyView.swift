import SwiftUI

// MARK: - FantasyView — Phase-9
// ✔ .navigationTitle added for AppRootView shell
struct FantasyView: View {
    var body: some View {
        FeaturePlaceholderView(
            title: "feature.fantasy.title",
            subtitle: "feature.fantasy.subtitle",
            systemImage: "trophy.fill"
        )
        .navigationTitle("tab.fantasy")
        .navigationBarTitleDisplayMode(.large)
    }
}
