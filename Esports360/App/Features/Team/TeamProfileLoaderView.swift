import SwiftUI

// MARK: - TeamProfileLoaderView — Phase-12 Final
// ✔ E360SkeletonList(.teamCard) replaces SkeletonRow
// ✔ .task async load replaces .onAppear
// ✔ E360StatusBanner on error + retry state

struct TeamProfileLoaderView: View {
    let teamId: String

    @State private var profile:  TeamProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var retryToken  = 0

    private let repository = BackendTeamRepository()

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    E360SkeletonList(type: .teamCard, count: 3)
                    Spacer()
                }
                .padding(18)
                .background(E360Color.background.ignoresSafeArea())

            } else if let profile {
                TeamProfileView(profile: profile)

            } else {
                VStack(spacing: 20) {
                    E360StatusBanner(
                        style: .error(
                            errorMessage ?? String(localized: "discover.error.loading",
                                defaultValue: "حدث خطأ أثناء تحميل البيانات")
                        ),
                        onDismiss: nil
                    )

                    Button(String(localized: "discover.retry", defaultValue: "إعادة المحاولة")) {
                        errorMessage = nil
                        retryToken  += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(E360Color.primary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(E360Color.background.ignoresSafeArea())
            }
        }
        .task(id: retryToken) { await loadProfile() }
    }

    @MainActor
    private func loadProfile() async {
        isLoading     = true
        errorMessage  = nil
        do {
            profile   = try await repository.teamProfile(id: teamId)
        } catch {
            if let mock = MockEsportsData.teamProfile(id: teamId) {
                profile = mock
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}
