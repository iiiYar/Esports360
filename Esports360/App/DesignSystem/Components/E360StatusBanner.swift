import SwiftUI

// MARK: - E360StatusBanner
// Inline status banners for: offline, loading, warning, error, success
// Sticky at top of screen or inline within scroll views
//
// Usage:
//   E360StatusBanner(style: .offline)
//   E360StatusBanner(style: .success("تم الحفظ"))
//   E360StatusBanner(style: .warning("البيانات قديمة"), onDismiss: { ... })

enum E360BannerStyle {
    case offline
    case reconnecting
    case syncing
    case success(String)
    case warning(String)
    case error(String)
    case info(String)
    case live

    var icon: String {
        switch self {
        case .offline:       return "wifi.slash"
        case .reconnecting:  return "arrow.clockwise.icloud"
        case .syncing:       return "arrow.triangle.2.circlepath"
        case .success:       return "checkmark.circle.fill"
        case .warning:       return "exclamationmark.triangle.fill"
        case .error:         return "xmark.octagon.fill"
        case .info:          return "info.circle.fill"
        case .live:          return "dot.radiowaves.left.and.right"
        }
    }

    var color: Color {
        switch self {
        case .offline, .reconnecting: return E360Color.warning
        case .syncing:                return E360Color.accent
        case .success:                return E360Color.success
        case .warning:                return E360Color.gold
        case .error:                  return E360Color.error
        case .info:                   return E360Color.primaryBright
        case .live:                   return E360Color.live
        }
    }

    var message: String {
        switch self {
        case .offline:       return String(localized: "banner.offline",      defaultValue: "لا يوجد اتصال — عرض آخر بيانات")
        case .reconnecting:  return String(localized: "banner.reconnecting",  defaultValue: "جارٍ إعادة الاتصال…")
        case .syncing:       return String(localized: "banner.syncing",       defaultValue: "جارٍ مزامنة البيانات…")
        case .live:          return String(localized: "banner.live",          defaultValue: "بث مباشر — النتائج تتحدّث فوريًا")
        case .success(let m):  return m
        case .warning(let m):  return m
        case .error(let m):    return m
        case .info(let m):     return m
        }
    }

    var isAnimated: Bool {
        switch self {
        case .reconnecting, .syncing, .live: return true
        default: return false
        }
    }
}

struct E360StatusBanner: View {
    let style: E360BannerStyle
    var onDismiss: (() -> Void)? = nil
    var compact: Bool = false

    @State private var rotating = false

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                if style.isAnimated && !compact {
                    Circle()
                        .fill(style.color.opacity(0.12))
                        .frame(width: 28, height: 28)
                        .scaleEffect(rotating ? 1.15 : 0.92)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: rotating)
                }
                Image(systemName: style.icon)
                    .font(.system(size: compact ? 12 : 14, weight: .bold))
                    .foregroundStyle(style.color)
                    .rotationEffect(style.isAnimated ? .degrees(rotating ? 360 : 0) : .zero)
                    .animation(
                        style.isAnimated
                            ? .linear(duration: 1.8).repeatForever(autoreverses: false)
                            : .default,
                        value: rotating
                    )
            }

            // Message
            Text(style.message)
                .font(compact
                    ? E360Font.body(11, weight: .semibold)
                    : E360Font.body(13, weight: .semibold))
                .foregroundStyle(E360Color.textPrimary)
                .lineLimit(1)

            Spacer()

            // Dismiss
            if let onDismiss {
                Button {
                    HapticManager.shared.triggerImpact(style: .light)
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(E360Color.textTertiary)
                        .padding(6)
                        .background(E360Color.tintedSurface, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, compact ? 8 : 12)
        .background {
            RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                .fill(style.color.opacity(0.09))
            RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                .stroke(style.color.opacity(0.22), lineWidth: 1)
        }
        .onAppear { rotating = style.isAnimated }
    }
}

// MARK: - ViewModifier for inline banners
extension View {
    /// Overlays a sticky banner at the top of a view when condition is true
    func e360Banner(_ style: E360BannerStyle, isVisible: Bool, onDismiss: (() -> Void)? = nil) -> some View {
        ZStack(alignment: .top) {
            self
            if isVisible {
                E360StatusBanner(style: style, onDismiss: onDismiss, compact: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.80), value: isVisible)
    }
}
