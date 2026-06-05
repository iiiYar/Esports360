import SwiftUI

struct TeamAvatar: View {
    let team: Team?
    let size: CGFloat
    var game: EsportsGame? = nil
    var isLive: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(E360Color.elevatedSurface)
                .overlay(
                    Circle()
                        .stroke(
                            (isLive && game != nil) ? game!.themeColor.opacity(0.55) : E360Color.divider,
                            lineWidth: (isLive && game != nil) ? 2 : 1
                        )
                )
                .shadow(color: (isLive && game != nil) ? game!.themeColor.opacity(0.36) : E360Color.primary.opacity(0.08), radius: (isLive && game != nil) ? 8 : 4)

            if let imageURL = team?.imageURL {
                ESImageView(url: imageURL, fallbackAsset: E360ImageAsset.teamPlaceholder)
                    .padding(6)
            } else {
                ESImageView(url: nil, fallbackAsset: E360ImageAsset.teamPlaceholder, fallbackText: team?.displayName)
                    .opacity(0.36)
                    .padding(6)
            }
        }
        .frame(width: size, height: size)
    }
}
