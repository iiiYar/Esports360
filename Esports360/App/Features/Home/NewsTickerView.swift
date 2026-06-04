import SwiftUI

struct NewsTickerView: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Image(systemName: "newspaper.fill")
                    .foregroundStyle(E360Color.gold)

                ForEach(items, id: \.self) { item in
                    Text(LocalizedStringKey(item))
                        .font(E360Font.body(13, weight: .semibold))
                        .foregroundStyle(E360Color.textPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(E360Color.elevatedSurface, in: Capsule())
                }
            }
            .padding(.vertical, 2)
        }
    }
}
