import SwiftUI

// MARK: - E360Chip
// Multi-purpose selection chip: game filters, categories, tags, toggles
//
// Usage — single:
//   E360Chip(label: "CS2", icon: "gamecontroller", isSelected: $selected)
//
// Usage — group (radio):
//   E360ChipGroup(options: games, selected: $selectedGame)

struct E360Chip: View {
    let label: String
    var icon: String?          = nil
    var image: Image?          = nil
    var badge: String?         = nil
    var color: Color           = E360Color.accent
    @Binding var isSelected: Bool

    var body: some View {
        Button {
            HapticManager.shared.triggerSelection()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                isSelected.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                // Leading icon / image
                if let image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isSelected ? color : E360Color.textTertiary)
                }

                // Label
                Text(label)
                    .font(E360Font.body(13, weight: isSelected ? .black : .semibold))
                    .foregroundStyle(isSelected ? color : E360Color.textSecondary)

                // Badge
                if let badge {
                    Text(badge)
                        .font(E360Font.mono(10, weight: .bold))
                        .foregroundStyle(isSelected ? color : E360Color.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background((isSelected ? color : E360Color.textTertiary).opacity(0.15),
                                     in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule().fill(color.opacity(0.14))
                    Capsule().stroke(color.opacity(0.35), lineWidth: 1.2)
                } else {
                    Capsule().fill(E360Color.tintedSurface)
                    Capsule().stroke(E360Color.dividerStrong, lineWidth: 1)
                }
            }
        }
        .buttonStyle(E360PressScale(scale: 0.94))
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isSelected)
    }
}

// MARK: - E360ChipGroup (radio single-select)
struct E360ChipGroup<T: Hashable & CustomStringConvertible>: View {
    let options: [T]
    @Binding var selected: T?
    var color: Color = E360Color.accent
    var iconProvider: ((T) -> String?)? = nil
    var badgeProvider: ((T) -> String?)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.hashValue) { option in
                    let isSel = selected == option
                    Button {
                        HapticManager.shared.triggerSelection()
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                            selected = isSel ? nil : option
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let icon = iconProvider?(option) {
                                Image(systemName: icon)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(isSel ? color : E360Color.textTertiary)
                            }
                            Text(option.description)
                                .font(E360Font.body(13, weight: isSel ? .black : .semibold))
                                .foregroundStyle(isSel ? color : E360Color.textSecondary)
                            if let badge = badgeProvider?(option) {
                                Text(badge)
                                    .font(E360Font.mono(10, weight: .bold))
                                    .foregroundStyle(isSel ? color : E360Color.textTertiary)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background((isSel ? color : E360Color.textTertiary).opacity(0.15), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if isSel {
                                Capsule().fill(color.opacity(0.14))
                                Capsule().stroke(color.opacity(0.35), lineWidth: 1.2)
                            } else {
                                Capsule().fill(E360Color.tintedSurface)
                                Capsule().stroke(E360Color.dividerStrong, lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(E360PressScale(scale: 0.94))
                    .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isSel)
                }
            }
            .padding(.horizontal, 18)
        }
    }
}

// MARK: - "All" chip convenience
struct E360AllChip: View {
    @Binding var isSelected: Bool
    var color: Color = E360Color.accent

    var body: some View {
        E360Chip(
            label: String(localized: "chip.all", defaultValue: "الكل"),
            icon: "square.grid.2x2",
            color: color,
            isSelected: $isSelected
        )
    }
}
