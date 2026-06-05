import SwiftUI

// Legacy shim — kept for any callsites not yet migrated to E360EmptyState
// TODO: Remove after Phase-4 screen updates
typealias EmptySectionView = _LegacyEmptySectionView

struct _LegacyEmptySectionView: View {
    var title: String = "لا توجد بيانات"
    var subtitle: String = ""
    var icon: String = "tray"
    var body: some View {
        E360EmptyState(
            style: .custom(icon: icon, title: title, subtitle: subtitle, iconColor: E360Color.textTertiary)
        )
    }
}
