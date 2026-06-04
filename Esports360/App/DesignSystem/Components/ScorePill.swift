import SwiftUI

struct ScorePill: View {
    let score: String
    let isLeading: Bool

    var body: some View {
        Text(score)
            .font(E360Font.number(34, weight: .black))
            .foregroundStyle(isLeading ? E360Color.accent : E360Color.textPrimary)
            .minimumScaleFactor(0.65)
            .contentTransition(.numericText())
            .frame(width: 50, height: 42)
            .background(E360Color.elevatedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isLeading ? E360Color.accent.opacity(0.55) : E360Color.divider, lineWidth: 1)
            )
            .shadow(color: isLeading ? E360Color.accent.opacity(0.18) : .clear, radius: 10)
    }
}
