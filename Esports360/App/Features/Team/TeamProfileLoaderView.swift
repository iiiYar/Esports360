import SwiftUI

struct TeamProfileLoaderView: View {
    let teamId: String
    @State private var profile: TeamProfile? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    private let repository = BackendTeamRepository()

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    SkeletonRow(height: 180, cornerRadius: 12)
                    SkeletonRow(height: 140, cornerRadius: 12)
                    SkeletonRow(height: 200, cornerRadius: 12)
                    Spacer()
                }
                .padding()
                .background(E360Color.background.ignoresSafeArea())
                .onAppear {
                    loadProfile()
                }
            } else if let profile = profile {
                TeamProfileView(profile: profile)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundStyle(E360Color.live)
                    
                    Text(errorMessage ?? String(localized: "discover.error.loading", defaultValue: "حدث خطأ أثناء تحميل البيانات"))
                        .font(E360Font.body(14, weight: .bold))
                        .foregroundStyle(E360Color.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button(String(localized: "discover.retry", defaultValue: "إعادة المحاولة")) {
                        loadProfile()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(E360Color.primary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(E360Color.background.ignoresSafeArea())
            }
        }
    }

    private func loadProfile() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetchedProfile = try await repository.teamProfile(id: teamId)
                await MainActor.run {
                    self.profile = fetchedProfile
                    self.isLoading = false
                }
            } catch {
                // Fallback to mock data if remote fails or is unavailable
                if let mock = MockEsportsData.teamProfile(id: teamId) {
                    await MainActor.run {
                        self.profile = mock
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                }
            }
        }
    }
}
