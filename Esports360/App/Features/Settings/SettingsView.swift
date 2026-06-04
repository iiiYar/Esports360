import SwiftUI

struct SettingsView: View {
    @AppStorage(AppStorageKeys.languageCode) private var languageCode = AppLanguage.arabic.rawValue
    @AppStorage(AppStorageKeys.calendarIdentifier) private var calendarIdentifier = E360CalendarPreference.gregorian.rawValue
    @AppStorage(AppStorageKeys.backendBaseURL) private var backendBaseURL = E360Constants.defaultBackendBaseURL
    @AppStorage(AppStorageKeys.matchRemindersEnabled) private var matchRemindersEnabled = false
    @AppStorage("app.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @StateObject private var authService = UserAuthService.shared
    @State private var logoCacheSize: String = "..."
    @State private var isDeletingAccount = false
    @State private var authError = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Premium Dynamic User Header
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(E360Color.elevatedSurface)
                                .frame(width: 84, height: 84)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [E360Color.primary, E360Color.accent],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .shadow(color: E360Color.primary.opacity(0.16), radius: 12)

                            Image(systemName: authService.isLoggedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.questionmark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 84, height: 84)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [E360Color.primary.opacity(0.85), E360Color.accent.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text(authService.isLoggedIn ? (authService.currentUser?.displayName ?? "مستخدم Esports360") : "زائر التطبيق")
                            .font(E360Font.display(22, weight: .black))
                            .foregroundStyle(E360Color.textPrimary)

                        if authService.isLoggedIn, let email = authService.currentUser?.email {
                            Text(email)
                                .font(E360Font.mono(12, weight: .bold))
                                .foregroundStyle(E360Color.textSecondary)
                        } else {
                            Button {
                                HapticManager.shared.triggerSelection()
                                withAnimation {
                                    hasCompletedOnboarding = false
                                }
                            } label: {
                                Text("تسجيل الدخول / إنشاء حساب 🔐")
                                    .font(E360Font.body(12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(
                                            colors: [E360Color.primary, E360Color.accent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        in: Capsule()
                                    )
                                    .shadow(color: E360Color.primary.opacity(0.3), radius: 8)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 10)

                    // 1. Language Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("settings.language", systemImage: "character.bubble.fill")
                            .font(E360Font.body(14, weight: .bold))
                            .foregroundStyle(E360Color.accent)

                        Picker("", selection: $languageCode) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(16)
                    .e360GlassCard()

                    // 2. Calendar Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("settings.calendar", systemImage: "calendar")
                            .font(E360Font.body(14, weight: .bold))
                            .foregroundStyle(E360Color.primary)

                        Picker("", selection: $calendarIdentifier) {
                            Text("calendar.gregorian").tag(E360CalendarPreference.gregorian.rawValue)
                            Text("calendar.hijri").tag(E360CalendarPreference.hijri.rawValue)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(16)
                    .e360GlassCard()

                    // 3. Notifications Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("settings.notifications", systemImage: "bell.fill")
                            .font(E360Font.body(14, weight: .bold))
                            .foregroundStyle(E360Color.gold)

                        Toggle("settings.matchReminders", isOn: $matchRemindersEnabled)
                            .font(E360Font.body(15, weight: .semibold))
                            .tint(E360Color.accent)

                        Text("settings.matchRemindersFootnote")
                            .font(E360Font.body(12, weight: .medium))
                            .foregroundStyle(E360Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .e360GlassCard()

                    // 4. API URL Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("settings.api", systemImage: "network")
                            .font(E360Font.body(14, weight: .bold))
                            .foregroundStyle(E360Color.accent)

                        TextField("settings.backendURL", text: $backendBaseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .font(E360Font.mono(13, weight: .medium))
                            .padding(12)
                            .background(E360Color.elevatedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(E360Color.divider, lineWidth: 1))

                        Text("settings.apiFootnote")
                            .font(E360Font.body(12, weight: .medium))
                            .foregroundStyle(E360Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .e360GlassCard()

                    // Account Data & Security Card (Only if logged in)
                    if authService.isLoggedIn {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("بيانات الحساب والأمان", systemImage: "shield.lefthalf.filled")
                                .font(E360Font.body(14, weight: .bold))
                                .foregroundStyle(.red)

                            if !authError.isEmpty {
                                Text(authError)
                                    .font(E360Font.body(12, weight: .bold))
                                    .foregroundStyle(.red)
                            }

                            // Logout Button
                            Button {
                                HapticManager.shared.triggerSelection()
                                Task {
                                    await authService.logout()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.forward")
                                        .foregroundStyle(.orange)
                                    Text("تسجيل الخروج")
                                        .font(E360Font.body(15, weight: .bold))
                                        .foregroundStyle(E360Color.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.backward")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(E360Color.textTertiary)
                                }
                            }

                            Divider().background(E360Color.divider)

                            // Delete Account Button (Apple Guidelines Compliant)
                            Button {
                                HapticManager.shared.triggerImpact(style: .heavy)
                                isDeletingAccount = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.crop.circle.fill.badge.xmark")
                                        .foregroundStyle(.red)
                                    Text("حذف الحساب نهائياً")
                                        .font(E360Font.body(15, weight: .bold))
                                        .foregroundStyle(.red)
                                    Spacer()
                                    Image(systemName: "chevron.backward")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(E360Color.textTertiary)
                                }
                            }
                            .confirmationDialog(
                                "هل أنت متأكد من حذف الحساب نهائياً؟",
                                isPresented: $isDeletingAccount,
                                titleVisibility: .visible
                            ) {
                                Button("حذف الحساب الشخصي", role: .destructive) {
                                    Task {
                                        do {
                                            try await authService.deleteAccount()
                                        } catch {
                                            authError = error.localizedDescription
                                        }
                                    }
                                }
                                Button("إلغاء", role: .cancel) {}
                            } message: {
                                Text("سيتم إزالة تفضيلاتك ومتابعاتك وكافة بياناتك المسجلة فوراً من خوادمنا بشكل كامل وغير قابل للاسترجاع.")
                            }
                        }
                        .padding(16)
                        .e360GlassCard()
                    }

                    // 5. Developer Tools Card
                    VStack(alignment: .leading, spacing: 16) {
                        Label("خيارات المطور (مؤقت)", systemImage: "hammer.fill")
                            .font(E360Font.body(14, weight: .bold))
                            .foregroundStyle(.orange)

                        Button {
                            HapticManager.shared.triggerNotification(type: .success)
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
                                hasCompletedOnboarding = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: "hand.wave.fill")
                                    .foregroundStyle(E360Color.accent)
                                Text("إعادة عرض الرسالة الترحيبية")
                                    .font(E360Font.body(15, weight: .bold))
                                    .foregroundStyle(E360Color.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.backward")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(E360Color.textTertiary)
                            }
                        }

                        Divider().background(E360Color.divider)

                        HStack {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 18))
                                .foregroundStyle(E360Color.primary)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("ذاكرة الشعارات المحلية")
                                    .font(E360Font.body(15, weight: .bold))
                                    .foregroundStyle(E360Color.textPrimary)
                                Text("الحجم: \(logoCacheSize)")
                                    .font(E360Font.body(12, weight: .medium))
                                    .foregroundStyle(E360Color.textSecondary)
                            }
                            Spacer()
                        }

                        HStack(spacing: 12) {
                            Button {
                                HapticManager.shared.triggerImpact(style: .medium)
                                Task {
                                    await ImageDiskCache.shared.clearCache()
                                    await refreshCacheSize()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("مسح الكاش")
                                }
                                .font(E360Font.body(13, weight: .bold))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.red.opacity(0.24), lineWidth: 1))
                            }

                            Button {
                                HapticManager.shared.triggerImpact(style: .light)
                                LogoPrefetcher.prefetchAll()
                                Task {
                                    try? await Task.sleep(for: .seconds(3))
                                    await refreshCacheSize()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("تحميل الشعارات")
                                }
                                .font(E360Font.body(13, weight: .bold))
                                .foregroundStyle(E360Color.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(E360Color.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(E360Color.accent.opacity(0.24), lineWidth: 1))
                            }
                        }
                    }
                    .padding(16)
                    .e360GlassCard()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 100)
            }
            .background(E360Color.background.ignoresSafeArea())
            .navigationTitle("tab.settings")
            .task {
                await refreshCacheSize()
            }
            .onChange(of: languageCode) { _, _ in
                syncWithBackend()
            }
            .onChange(of: calendarIdentifier) { _, _ in
                syncWithBackend()
            }
            .onChange(of: matchRemindersEnabled) { _, _ in
                syncWithBackend()
            }
        }
    }

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
        
        Task {
            await authService.syncPreferences(newPrefs: localPrefs)
        }
    }

    private func refreshCacheSize() async {
        let bytes = await ImageDiskCache.shared.diskUsage
        if bytes < 1024 {
            logoCacheSize = "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            logoCacheSize = String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            logoCacheSize = String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
}
