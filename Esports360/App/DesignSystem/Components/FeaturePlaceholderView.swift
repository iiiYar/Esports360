import SwiftUI

struct FeaturePlaceholderView: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String

    var body: some View {
        ZStack {
            E360Color.background.ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(E360Color.primary)

                Text(title)
                    .e360ScreenTitle()
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(E360Font.body(15, weight: .medium))
                    .foregroundStyle(E360Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(24)
        }
    }
}
