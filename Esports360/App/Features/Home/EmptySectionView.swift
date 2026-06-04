import SwiftUI

struct EmptySectionView: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(E360Font.body(14, weight: .medium))
            .foregroundStyle(E360Color.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(E360Color.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(E360Color.divider, lineWidth: 1)
            )
    }
}
