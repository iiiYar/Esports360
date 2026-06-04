import SwiftUI

struct SettingsView: View {
    @AppStorage(AppStorageKeys.languageCode)          private var languageCode          = AppLanguage.arabic.rawValue
    @AppStorage(AppStorageKeys.calendarIdentifier)    private var calendarIdentifier    = E360CalendarPreference.gregorian.rawValue
    @AppStorage(AppStorageKeys.backendBaseURL)        private var backendBaseURL        = E360Constants.defaultBackendBaseURL
    @AppStorage(AppStorageKeys.matchRemindersEnabled) private var matchRemindersEnabled = false
    @AppStorage("app.hasCompletedOnboarding")         private var hasCompletedOnboarding = false

    @StateObject private var authService = UserAuthService.shared
    @State private var logoCacheSize: String = "..."
    @State private var isDeletingAccount = false
    @State private var authError = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    userHeader
                    languageCard
                    calendarCard
                    notificationsCard
                    apiCard
                    if authService.isLoggedIn { accountSecurityCard }
                    #if DEBUG
                    developerCard
                    #endif
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 100)
            }
            .background(E360Color.background.ignoresSafeArea())
            .navigationTitle("tab.settings")
            .task { await refreshCacheSize() }
            .onChange(of: languageCode)         { _, _ in syncWithBackend() }
            .onChange(of: calendarIdentifier)   { _, _ in syncWithBackend() }
            .onChange(of: matchRemindersEnabled) { _, _ in syncWithBackend() }
        }
    }

    // MARK: - User Header
    private var userHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(E360Color.elevatedSurface)
                    .frame(width: 84, height: 84)
                    .overlay(Circle().stroke(
                        LinearGradient(colors: [E360Color.primary, E360Color.accent],
                            startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
                    .shadow(color: E360Color.primary.opacity(0.16), radius: 12)
                Image(systemName: authService.isLoggedIn
                        ? "person.crop.circle.badge.checkmark"
                        : "person.crop.circle.badge.questionmark")
                    .resizable().scaledToFit().frame(width: 84, height: 84)
                    .foregroundStyle(LinearGradient(
                        colors: [E360Color.primary.opacity(0.85), E360Color.accent.opacity(0.85)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Text(authService.isLoggedIn
                    ? (authService.currentUser?.displayName ?? String(localized: "settings.defaultUser", defaultValue: "مستخدم Esports360"))
                    : String(localized: "settings.guest", defaultValue: "زائر التطبيق"))
                .font(E360Font.display(22, weight: .black)).foregroundStyle(E360Color.textPrimary)

            if authService.isLoggedIn, let email = authService.currentUser?.email {
                Text(email).font(E360Font.mono(12, weight: .bold)).foregroundStyle(E360Color.textSecondary)
            } else {
                Button {
                    HapticManager.shared.triggerSelection()
                    withAnimation { hasCompletedOnboarding = false }
                } label: {
                    Text(String(localized: "settings.loginCTA", defaultValue: "تسجيل الدخول / إنشاء حساب 🔐"))
                        .font(E360Font.body(12, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(LinearGradient(colors: [E360Color.primary, E360Color.accent],
                            startPoint: .leading, endPoint: .trailing), in: Capsule())
                        .shadow(color: E360Color.primary.opacity(0.3), radius: 8)
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 24).padding(.bottom, 10)
    }

    // MARK: - Language Card
    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("settings.language", systemImage: "character.bubble.fill")
                .font(E360Font.body(14, weight: .bold)).foregroundStyle(E360Color.accent)
            Picker("", selection: $languageCode) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16).e360GlassCard()
    }

    // MARK: - Calendar Card
    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("settings.calendar", systemImage: "calendar")
                .font(E360Font.body(14, weight: .bold)).foregroundStyle(E360Color.primary)
            Picker("", selection: $calendarIdentifier) {
                Text("calendar.gregorian").tag(E360CalendarPreference.gregorian.rawValue)
                Text("calendar.hijri").tag(E360CalendarPreference.hijri.rawValue)
            }
            .pickerStyle(.segmented)
        }
        .padding(16).e360GlassCard()
    }

    // MARK: - Notifications Card
    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("settings.notifications", systemImage: "bell.fill")
                .font(E360Font.body(14, weight: .bold)).foregroundStyle(E360Color.gold)
            Toggle("settings.matchReminders", isOn: $matchRemindersEnabled)
                .font(E360Font.body(15, weight: .semibold)).tint(E360Color.accent)
            Text("settings.matchRemindersFootnote")
                .font(E360Font.body(12, weight: .medium))
                .foregroundStyle(E360Color.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16).e360GlassCard()
    }

    // MARK: - API Card
    private var apiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("settings.api", systemImage: "network")
                .font(E360Font.body(14, weight: .bold)).foregroundStyle(E360Color.accent)
            TextField("settings.backendURL", text: $backendBaseURL)
                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                .font(E360Font.mono(13, weight: .medium)).padding(12)
                .background(E360Color.elevatedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(E360Color.divider, lineWidth: 1))
            Text("settings.apiFootnote")
                .font(E360Font.body(12, weight: .medium))
                .foregroundStyle(E360Color.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16).e360GlassCard()
    }

    // MARK: - Account Security Card
    private var accountSecurityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(String(localized: "settings.accountSecurity", defaultValue: "بيانات الحساب والأمان"),
                  systemImage: "shield.lefthalf.filled")
                .font(E360Font.body(14, weight: .bold)).foregroundStyle(.red)

            if !authError.isEmpty {
                Text(authError).font(E360Font.body(12, weight: .bold)).foregroundStyle(.red)
            }

            Button {
                HapticManager.shared.triggerSelection()
                Task { await authService.logout() }
            } label: {
                settingsRow(
                    icon: "rectangle.portrait.and.arrow.forward", iconColor: .orange,
                    label: String(localized: "settings.logout", defaultValue: "تسجيل الخروج")
                )
            }

            Divider().background(E360Color.divider)

            Button {
                HapticManager.shared.triggerImpact(style: .heavy)
                isDeletingAccount = true
            } label: {
                settingsRow(
                    icon: "person.crop.circle.fill.badge.xmark", iconColor: .red,
                    label: String(localized: "settings.deleteAccount", defaultValue: "حذف الحساب نهائياً"),
                    labelColor: .red
                )
            }
            .confirmationDialog(
                String(localized: "settings.deleteAccountConfirmTitle",
                    defaultValue: "هل أنت متأكد من حذف الحساب نهائياً؟"),
                isPresented: $isDeletingAccount,
                titleVisibility: .visible
            ) {
                Button(String(localized: "settings.deleteAccountAction",
                    defaultValue: "حذف الحساب الشخصي"), role: .destructive) {
                    Task {
                        do {
                            try await authService.deleteAccount()
                        } catch {
                            authError = error.localizedDescription
                        }
                    }
                }
                Button(String(localized: "common.cancel", defaultValue: "إلغاء"), role: .cancel) {}
            } message: {
                Text(String(localized: "settings.deleteAccountMessage",
                    defaultValue: "سيتم إزالة تفضيلاتك ومتابعاتك وكافة بياناتك فوراً بشكل غير قابل للاسترجاع."))
            }
        }
        .padding(16).e360GlassCard()
    }

    // MARK: - Developer Card (DEBUG only)
    #if DEBUG
    private var developerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(String(localized: "settings.devTools", defaultValue: "خيارات المطور (مؤقت)"),
                  systemImage: "hammer.fill")
                .font(E360Font.body(14, weight: .bold)).foregroundStyle(.orange)

            Button {
                HapticManager.shared.triggerNotification(type: .success)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
                    hasCompletedOnboarding = false
                }
            } label: {
                settingsRow(
                    icon: "hand.wave.fill", iconColor: E360Color.accent,
                    label: String(localized: "settings.replayOnboarding", defaultValue: "إعادة عرض الرسالة الترحيبية")
                )
            }

            Divider().background(E360Color.divider)

            HStack {
                Image(systemName: "photo.stack").font(.system(size: 18)).foregroundStyle(E360Color.primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "settings.localLogoCache", defaultValue: "ذاكرة الشعارات المحلية"))
                        .font(E360Font.body(15, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                    Text(String(format: String(localized: "settings.cacheSize", defaultValue: "الحجم: %@"), logoCacheSize))
                        .font(E360Font.body(12, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    HapticManager.shared.triggerImpact(style: .medium)
                    Task { await ImageDiskCache.shared.clearCache(); await refreshCacheSize() }
                } label: {
                    Label(String(localized: "settings.clearCache", defaultValue: "مسح الكاش"), systemImage: "trash.fill")
                        .font(E360Font.body(13, weight: .bold)).foregroundStyle(.red)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.red.opacity(0.24), lineWidth: 1))
                }
                Button {
                    HapticManager.shared.triggerImpact(style: .light)
                    LogoPrefetcher.prefetchAll()
                    Task { try? await Task.sleep(for: .seconds(3)); await refreshCacheSize() }
                } label: {
                    Label(String(localized: "settings.prefetchLogos", defaultValue: "تحميل الشعارات"), systemImage: "arrow.down.circle.fill")
                        .font(E360Font.body(13, weight: .bold)).foregroundStyle(E360Color.accent)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(E360Color.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(E360Color.accent.opacity(0.24), lineWidth: 1))
                }
            }
        }
        .padding(16).e360GlassCard()
    }
    #endif

    // MARK: - Reusable Row
    private func settingsRow(icon: String, iconColor: Color, label: String, labelColor: Color = E360Color.textPrimary) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(iconColor)
            Text(label).font(E360Font.body(15, weight: .bold)).foregroundStyle(labelColor)
            Spacer()
            Image(systemName: "chevron.backward").font(.system(size: 14, weight: .bold)).foregroundStyle(E360Color.textTertiary)
        }
    }

    // MARK: - Helpers
    private func syncWithBackend() {
        guard authService.isLoggedIn else { return }
        let localPrefs = UserPreferences(
            language: languageCode,
            calendarPreference: calendarIdentifier,
            saudiFanMode: authService.preferences.saudiFanMode,
            notificationsEnabled: matchRemindersEnabled,
            notifMatchStart: authService.preferences.notifMatchStart,
            notifScoreChange: authService.preferences.notifScoreChange,
            notifMatchEnd: authService.preferences.notifMatchEnd,
            notifRosterChange: authService.preferences.notifRosterChange,
            notifStreamLive: authService.preferences.notifStreamLive,
            notifFantasyRemind: authService.preferences.notifFantasyRemind
        )
        Task { await authService.syncPreferences(newPrefs: localPrefs) }
    }

    private func refreshCacheSize() async {
        let bytes = await ImageDiskCache.shared.diskUsage
        logoCacheSize = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
