import SwiftUI
import OSLog

// MARK: - SettingsView — Phase-6
// ✔ NavigationStack removed — shell in AppRootView owns it
// ✔ .navigationTitle / .navigationBarTitleDisplayMode applied on the ZStack
// ✔ All E360SettingsSection / rows unchanged

struct SettingsView: View {

    // ── AppStorage ───────────────────────────────────────────────
    @AppStorage(AppStorageKeys.languageCode)          private var languageCode          = AppLanguage.arabic.rawValue
    @AppStorage(AppStorageKeys.calendarIdentifier)    private var calendarIdentifier    = E360CalendarPreference.gregorian.rawValue
    @AppStorage(AppStorageKeys.backendBaseURL)        private var backendBaseURL        = E360Constants.defaultBackendBaseURL
    @AppStorage(AppStorageKeys.matchRemindersEnabled) private var matchRemindersEnabled = false
    @AppStorage("app.hasCompletedOnboarding")         private var hasCompletedOnboarding = false

    // ── Services ────────────────────────────────────────────────
    @StateObject private var auth = UserAuthService.shared

    // ── Local state ────────────────────────────────────────────
    @State private var logoCacheSize: String = "—"
    @State private var showDeleteConfirm    = false
    @State private var authErrorMessage: String?
    @State private var showAuthError        = false

    // ── Notification toggles ──────────────────────────────────
    private var notifMatchStart:   Binding<Bool> { preferenceBool(\.notifMatchStart) }
    private var notifScoreChange:  Binding<Bool> { preferenceBool(\.notifScoreChange) }
    private var notifMatchEnd:     Binding<Bool> { preferenceBool(\.notifMatchEnd) }
    private var notifStreamLive:   Binding<Bool> { preferenceBool(\.notifStreamLive) }
    private var notifRosterChange: Binding<Bool> { preferenceBool(\.notifRosterChange) }
    private var notifFantasyRemind:Binding<Bool> { preferenceBool(\.notifFantasyRemind) }

    // ───────────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            E360Color.background.ignoresSafeArea()
            E360AmbientGlow(colors: [E360Color.primary.opacity(0.08), E360Color.accent.opacity(0.04), .clear])

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    userCard
                    appearanceSection
                    notificationsSection
                    if auth.isLoggedIn { accountSection }
                    #if DEBUG
                    developerSection
                    #endif
                    appInfoFooter
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle("tab.settings")
        .navigationBarTitleDisplayMode(.large)
        .task { await refreshCacheSize() }
        .onChange(of: languageCode)          { _, _ in syncPrefs() }
        .onChange(of: calendarIdentifier)    { _, _ in syncPrefs() }
        .onChange(of: matchRemindersEnabled) { _, _ in syncPrefs() }
        .alert("settings.authError", isPresented: $showAuthError, actions: {
            Button("common.ok", role: .cancel) {}
        }, message: {
            Text(authErrorMessage ?? "")
        })
    }

    // MARK: - User Card ───────────────────────────────────────
    private var userCard: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [E360Color.primary.opacity(0.22), E360Color.accent.opacity(0.10), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(E360Color.elevatedSurface)
                            .frame(width: 76, height: 76)
                            .overlay(
                                Circle().stroke(
                                    LinearGradient(
                                        colors: auth.isLoggedIn
                                            ? [E360Color.primary, E360Color.accent]
                                            : [E360Color.dividerStrong, E360Color.divider],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: auth.isLoggedIn ? 2.5 : 1.5
                                )
                            )
                            .shadow(color: auth.isLoggedIn ? E360Color.primaryGlow : .clear, radius: 14)

                        Image(systemName: auth.isLoggedIn
                            ? "person.crop.circle.fill"
                            : "person.crop.circle.badge.questionmark.fill")
                            .resizable().scaledToFit()
                            .frame(width: 42, height: 42)
                            .foregroundStyle(
                                auth.isLoggedIn
                                    ? LinearGradient(colors: [E360Color.primary, E360Color.accent], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [E360Color.textTertiary, E360Color.textTertiary], startPoint: .top, endPoint: .bottom)
                            )
                    }
                    .padding(.top, 20)

                    VStack(spacing: 4) {
                        Text(
                            auth.isLoggedIn
                                ? (auth.currentUser?.displayName ?? String(localized: "settings.defaultUser", defaultValue: "مستخدم Esports360"))
                                : String(localized: "settings.guest", defaultValue: "زائر")
                        )
                        .font(E360Font.display(20, weight: .black))
                        .foregroundStyle(E360Color.textPrimary)

                        if auth.isLoggedIn, let email = auth.currentUser?.email {
                            Text(email)
                                .font(E360Font.mono(12, weight: .medium))
                                .foregroundStyle(E360Color.textSecondary)
                        }
                    }

                    if !auth.isLoggedIn {
                        Button {
                            HapticManager.shared.triggerSelection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                hasCompletedOnboarding = false
                            }
                        } label: {
                            Label(
                                String(localized: "settings.loginCTA", defaultValue: "تسجيل الدخول"),
                                systemImage: "lock.open.fill"
                            )
                            .font(E360Font.body(14, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 24).padding(.vertical, 11)
                            .background(
                                LinearGradient(colors: [E360Color.accent, E360Color.accentBright],
                                               startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                            .shadow(color: E360Color.accentGlow, radius: 12)
                        }
                        .buttonStyle(E360PressScale(scale: 0.95))
                        .padding(.bottom, 4)
                    }

                    if auth.isLoggedIn {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(E360Color.accent)
                            Text(String(localized: "settings.verified", defaultValue: "حساب موثّق"))
                                .font(E360Font.body(12, weight: .bold)).foregroundStyle(E360Color.accent)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(E360Color.accentGlow, in: Capsule())
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .e360GlassCard(cornerRadius: 28, borderOpacity: 0.18, shadowRadius: 20, tintColor: E360Color.primary)
    }

    // MARK: - Appearance Section ──────────────────────────────
    private var appearanceSection: some View {
        E360SettingsSection(
            icon: "paintpalette.fill",
            title: String(localized: "settings.appearance", defaultValue: "المظهر والعرض"),
            accentColor: E360Color.accent
        ) {
            VStack(alignment: .leading, spacing: 10) {
                E360SettingsRowHeader(
                    icon: "character.bubble.fill",
                    label: String(localized: "settings.language", defaultValue: "اللغة"),
                    color: E360Color.accent
                )
                Picker("", selection: $languageCode) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.segmented).tint(E360Color.accent)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)

            E360SettingsDivider()

            VStack(alignment: .leading, spacing: 10) {
                E360SettingsRowHeader(
                    icon: "calendar",
                    label: String(localized: "settings.calendar", defaultValue: "نظام التقويم"),
                    color: E360Color.primary
                )
                Picker("", selection: $calendarIdentifier) {
                    Text(String(localized: "calendar.gregorian", defaultValue: "ميلادي"))
                        .tag(E360CalendarPreference.gregorian.rawValue)
                    Text(String(localized: "calendar.hijri", defaultValue: "هجري"))
                        .tag(E360CalendarPreference.hijri.rawValue)
                }
                .pickerStyle(.segmented).tint(E360Color.primary)
            }
            .padding(.horizontal, 16).padding(.vertical, 4).padding(.bottom, 14)
        }
    }

    // MARK: - Notifications Section ───────────────────────────
    private var notificationsSection: some View {
        E360SettingsSection(
            icon: "bell.badge.fill",
            title: String(localized: "settings.notifications", defaultValue: "الإشعارات"),
            accentColor: E360Color.gold
        ) {
            VStack(spacing: 0) {
                E360SettingsToggleRow(icon: "play.circle.fill",
                    label: String(localized: "settings.notif.matchStart", defaultValue: "بداية المباريات"),
                    color: E360Color.accent, isOn: notifMatchStart)
                E360SettingsDivider()
                E360SettingsToggleRow(icon: "bolt.fill",
                    label: String(localized: "settings.notif.scoreChange", defaultValue: "تغيير النتيجة"),
                    color: E360Color.gold, isOn: notifScoreChange)
                E360SettingsDivider()
                E360SettingsToggleRow(icon: "flag.checkered",
                    label: String(localized: "settings.notif.matchEnd", defaultValue: "نهاية المباريات"),
                    color: E360Color.primary, isOn: notifMatchEnd)
                E360SettingsDivider()
                E360SettingsToggleRow(icon: "play.tv.fill",
                    label: String(localized: "settings.notif.streamLive", defaultValue: "بث مباشر متاح"),
                    color: E360Color.live, isOn: notifStreamLive)
                E360SettingsDivider()
                E360SettingsToggleRow(icon: "person.2.fill",
                    label: String(localized: "settings.notif.rosterChange", defaultValue: "تغييرات الأطقم"),
                    color: E360Color.neonPurple, isOn: notifRosterChange)
                E360SettingsDivider()
                E360SettingsToggleRow(icon: "gamecontroller.fill",
                    label: String(localized: "settings.notif.fantasy", defaultValue: "تذكير الفانتازي"),
                    color: E360Color.neonGreen, isOn: notifFantasyRemind)
            }
        }
    }

    // MARK: - Account Section ─────────────────────────────────
    private var accountSection: some View {
        E360SettingsSection(
            icon: "shield.lefthalf.filled",
            title: String(localized: "settings.account", defaultValue: "الحساب والأمان"),
            accentColor: E360Color.live
        ) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    E360SettingsRowHeader(
                        icon: "network",
                        label: String(localized: "settings.api", defaultValue: "عنوان الخادم"),
                        color: E360Color.accent
                    )
                    TextField("settings.backendURL", text: $backendBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(E360Font.mono(13, weight: .medium))
                        .foregroundStyle(E360Color.textPrimary)
                        .padding(12)
                        .background(E360Color.tintedSurface,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(E360Color.dividerStrong, lineWidth: 1))
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

                E360SettingsDivider()

                Button {
                    HapticManager.shared.triggerSelection()
                    Task { await auth.logout() }
                } label: {
                    E360SettingsActionRow(
                        icon: "rectangle.portrait.and.arrow.forward",
                        label: String(localized: "settings.logout", defaultValue: "تسجيل الخروج"),
                        iconColor: E360Color.warning,
                        labelColor: E360Color.textPrimary
                    )
                }
                .buttonStyle(E360PressScale())

                E360SettingsDivider()

                Button {
                    HapticManager.shared.triggerImpact(style: .heavy)
                    showDeleteConfirm = true
                } label: {
                    E360SettingsActionRow(
                        icon: "person.crop.circle.badge.xmark.fill",
                        label: String(localized: "settings.deleteAccount", defaultValue: "حذف الحساب نهائياً"),
                        iconColor: E360Color.error, labelColor: E360Color.error
                    )
                }
                .buttonStyle(E360PressScale())
                .confirmationDialog(
                    String(localized: "settings.deleteAccountConfirmTitle",
                           defaultValue: "حذف الحساب نهائياً؟"),
                    isPresented: $showDeleteConfirm, titleVisibility: .visible
                ) {
                    Button(String(localized: "settings.deleteAccountAction",
                                  defaultValue: "نعم، احذف حسابي"), role: .destructive) {
                        Task {
                            do { try await auth.deleteAccount() }
                            catch { authErrorMessage = error.localizedDescription; showAuthError = true }
                        }
                    }
                    Button(String(localized: "common.cancel", defaultValue: "إلغاء"), role: .cancel) {}
                } message: {
                    Text(String(localized: "settings.deleteAccountMessage",
                                defaultValue: "سيتم حذف جميع بياناتك فوراً بشكل غير قابل للاسترجاع."))
                }
            }
        }
    }

    // MARK: - Developer Section (DEBUG) ───────────────────────
    #if DEBUG
    private var developerSection: some View {
        E360SettingsSection(
            icon: "hammer.fill",
            title: String(localized: "settings.devTools", defaultValue: "أدوات المطوّر"),
            accentColor: E360Color.neonOrange
        ) {
            VStack(spacing: 0) {
                Button {
                    HapticManager.shared.triggerNotification(type: .success)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
                        hasCompletedOnboarding = false
                    }
                } label: {
                    E360SettingsActionRow(
                        icon: "hand.wave.fill",
                        label: String(localized: "settings.replayOnboarding", defaultValue: "إعادة الترحيب"),
                        iconColor: E360Color.accent
                    )
                }
                .buttonStyle(E360PressScale())

                E360SettingsDivider()

                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(E360Color.primary.opacity(0.15)).frame(width: 36, height: 36)
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(E360Color.primary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.localLogoCache", defaultValue: "ذاكرة الشعارات"))
                            .font(E360Font.body(15, weight: .bold)).foregroundStyle(E360Color.textPrimary)
                        Text(logoCacheSize)
                            .font(E360Font.mono(12, weight: .medium)).foregroundStyle(E360Color.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)

                E360SettingsDivider()

                HStack(spacing: 10) {
                    Button {
                        HapticManager.shared.triggerImpact(style: .medium)
                        Task { await ImageDiskCache.shared.clearCache(); await refreshCacheSize() }
                    } label: {
                        Label(String(localized: "settings.clearCache", defaultValue: "مسح الكاش"),
                              systemImage: "trash.fill")
                            .font(E360Font.body(13, weight: .bold)).foregroundStyle(E360Color.error)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(E360Color.error.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(E360Color.error.opacity(0.22), lineWidth: 1))
                    }
                    .buttonStyle(E360PressScale())

                    Button {
                        HapticManager.shared.triggerImpact(style: .light)
                        LogoPrefetcher.prefetchAll()
                        Task { try? await Task.sleep(for: .seconds(3)); await refreshCacheSize() }
                    } label: {
                        Label(String(localized: "settings.prefetchLogos", defaultValue: "تحميل الشعارات"),
                              systemImage: "arrow.down.circle.fill")
                            .font(E360Font.body(13, weight: .bold)).foregroundStyle(E360Color.accent)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(E360Color.accentGlow,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(E360Color.accent.opacity(0.22), lineWidth: 1))
                    }
                    .buttonStyle(E360PressScale())
                }
                .padding(.horizontal, 16).padding(.bottom, 14)
            }
        }
    }
    #endif

    // MARK: - App Info Footer ────────────────────────────────
    private var appInfoFooter: some View {
        VStack(spacing: 6) {
            Text("Esports360")
                .font(E360Font.display(13, weight: .black)).foregroundStyle(E360Color.textTertiary)
            Text(String(localized: "settings.buildVersion", defaultValue: "الإصدار ۱.۰ · iOS 26"))
                .font(E360Font.mono(11, weight: .medium)).foregroundStyle(E360Color.textDisabled)
        }
        .frame(maxWidth: .infinity).padding(.bottom, 8)
    }

    // MARK: - Helpers ─────────────────────────────────────────
    private func syncPrefs() {
        guard auth.isLoggedIn else { return }
        let updated = UserPreferences(
            language:              languageCode,
            calendarPreference:    calendarIdentifier,
            saudiFanMode:          auth.preferences.saudiFanMode,
            notificationsEnabled:  matchRemindersEnabled,
            notifMatchStart:       auth.preferences.notifMatchStart,
            notifScoreChange:      auth.preferences.notifScoreChange,
            notifMatchEnd:         auth.preferences.notifMatchEnd,
            notifRosterChange:     auth.preferences.notifRosterChange,
            notifStreamLive:       auth.preferences.notifStreamLive,
            notifFantasyRemind:    auth.preferences.notifFantasyRemind
        )
        Task { await auth.syncPreferences(newPrefs: updated) }
    }

    private func preferenceBool(_ keyPath: WritableKeyPath<UserPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { auth.preferences[keyPath: keyPath] },
            set: { newValue in
                var updated = auth.preferences
                updated[keyPath: keyPath] = newValue
                HapticManager.shared.triggerSelection()
                Task { await auth.syncPreferences(newPrefs: updated) }
            }
        )
    }

    private func refreshCacheSize() async {
        let bytes = await ImageDiskCache.shared.diskUsage
        logoCacheSize = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - E360SettingsSection
struct E360SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    let accentColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(accentColor.opacity(0.18)).frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(accentColor)
                }
                Text(title)
                    .font(E360Font.body(14, weight: .black)).foregroundStyle(E360Color.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            Rectangle().fill(accentColor.opacity(0.12)).frame(height: 1).padding(.horizontal, 16)
            content()
        }
        .frame(maxWidth: .infinity)
        .e360GlassCard(cornerRadius: 22, borderOpacity: 0.13, shadowRadius: 14, tintColor: accentColor)
    }
}

// MARK: - E360SettingsRowHeader
struct E360SettingsRowHeader: View {
    let icon: String; let label: String; let color: Color
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            Text(label).font(E360Font.body(13, weight: .bold)).foregroundStyle(E360Color.textSecondary)
        }
    }
}

// MARK: - E360SettingsToggleRow
struct E360SettingsToggleRow: View {
    let icon: String; let label: String; let color: Color
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
            }
            Text(label).font(E360Font.body(15, weight: .semibold)).foregroundStyle(E360Color.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(color)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
    }
}

// MARK: - E360SettingsActionRow
struct E360SettingsActionRow: View {
    let icon: String; let label: String; let iconColor: Color
    var labelColor: Color = E360Color.textPrimary
    var showChevron: Bool = true
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(iconColor)
            }
            Text(label).font(E360Font.body(15, weight: .semibold)).foregroundStyle(labelColor)
            Spacer()
            if showChevron {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(E360Color.textTertiary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - E360SettingsDivider
struct E360SettingsDivider: View {
    var body: some View {
        Rectangle().fill(E360Color.divider).frame(height: 1).padding(.leading, 62)
    }
}
