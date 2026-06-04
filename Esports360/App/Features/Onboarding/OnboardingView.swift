import SwiftUI

struct OnboardingView: View {
    @AppStorage("app.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var authService = UserAuthService.shared
    @State private var currentStep = 0
    @State private var selectedGames: Set<EsportsGame> = [.leagueOfLegends, .counterStrike, .valorant]
    @State private var selectedTeams: Set<String> = ["Team Falcons"]
    
    @State private var isRegisterMode = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    @State private var showSocialLoginAlert = false
    @State private var socialProviderName = ""

    private let stepsCount = 4

    var body: some View {
        ZStack {
            // Deep dark background
            Color(hex: 0x080710).ignoresSafeArea()

            // Animated ambient particles
            OnboardingParticlesView()
                .ignoresSafeArea()

            // Ambient glow per step
            ambientGlow
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with skip button
                topNavBar

                // Pages
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    loginStep.tag(1)
                    gamesStep.tag(2)
                    teamsStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom controls
                bottomControls
            }
        }
        .preferredColorScheme(.dark)
        .alert("قريباً", isPresented: $showSocialLoginAlert) {
            Button("حسناً", role: .cancel) {}
        } message: {
            Text("ميزة تسجيل الدخول عبر \(socialProviderName) ستكون متاحة في التحديث القادم. يرجى استخدام التسجيل بالبريد الإلكتروني حالياً.")
        }
    }

    // MARK: - Ambient Glow

    private var ambientGlow: some View {
        ZStack {
            switch currentStep {
            case 0:
                Circle()
                    .fill(E360Color.primary.opacity(0.18))
                    .frame(width: 360, height: 360)
                    .blur(radius: 100)
                    .offset(x: -60, y: -180)
                Circle()
                    .fill(E360Color.gold.opacity(0.10))
                    .frame(width: 320, height: 320)
                    .blur(radius: 90)
                    .offset(x: 120, y: 200)
            case 1:
                Circle()
                    .fill(E360Color.accent.opacity(0.14))
                    .frame(width: 400, height: 400)
                    .blur(radius: 110)
                    .offset(x: 0, y: 60)
                Circle()
                    .fill(E360Color.primary.opacity(0.10))
                    .frame(width: 280, height: 280)
                    .blur(radius: 80)
                    .offset(x: -100, y: -200)
            case 2:
                let leadColor = selectedGames.first?.themeColor ?? E360Color.accent
                Circle()
                    .fill(leadColor.opacity(0.16))
                    .frame(width: 380, height: 380)
                    .blur(radius: 100)
                    .offset(x: 0, y: -40)
            default:
                Circle()
                    .fill(Color(hex: 0x00a15c).opacity(0.14))
                    .frame(width: 360, height: 360)
                    .blur(radius: 100)
                    .offset(x: -80, y: -120)
                Circle()
                    .fill(E360Color.gold.opacity(0.10))
                    .frame(width: 300, height: 300)
                    .blur(radius: 90)
                    .offset(x: 100, y: 140)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: currentStep)
    }

    // MARK: - Top Nav Bar

    private var topNavBar: some View {
        HStack {
            if currentStep > 0 {
                Button {
                    HapticManager.shared.triggerSelection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        currentStep -= 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                        Text("السابق")
                    }
                    .font(E360Font.body(14, weight: .bold))
                    .foregroundStyle(E360Color.textSecondary)
                }
            }

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                Text("تخطي")
                    .font(E360Font.body(14, weight: .bold))
                    .foregroundStyle(E360Color.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(E360Color.accent.opacity(0.25), lineWidth: 1))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Step 1: Cinematic Welcome

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            Spacer()

            // Pulsing crown with neon glow
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [E360Color.gold.opacity(0.4), E360Color.primary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 170, height: 170)
                    .modifier(PulseAnimation())

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [E360Color.primary.opacity(0.12), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 130, height: 130)
                    .overlay(Circle().stroke(E360Color.gold.opacity(0.25), lineWidth: 1.5))

                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [E360Color.gold, E360Color.primary, E360Color.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: E360Color.gold.opacity(0.5), radius: 16)
            }
            .padding(.bottom, 8)

            VStack(spacing: 14) {
                Text(E360Constants.arabicBrandName)
                    .font(E360Font.hero(42, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [E360Color.textPrimary, E360Color.textPrimary.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: E360Color.primary.opacity(0.3), radius: 8)

                Text(E360Constants.arabicTagline)
                    .font(E360Font.display(20, weight: .bold))
                    .foregroundStyle(E360Color.accent)
                    .shadow(color: E360Color.accent.opacity(0.4), radius: 6)
            }

            Text("منصتك العربية الأولى لمتابعة نتائج وإحصائيات بطولات الرياضات الإلكترونية المفضلة لديك بنقرة زر واحدة.")
                .font(E360Font.body(15, weight: .medium))
                .foregroundStyle(E360Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .lineSpacing(5)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 2: Glassmorphic Login

    @State private var loginEmail = ""
    @State private var loginPassword = ""
    @State private var showPassword = false

    private var loginStep: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text(isRegisterMode ? "إنشاء حساب ✨" : "تسجيل الدخول 🔐")
                    .font(E360Font.hero(32, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)

                Text(isRegisterMode ? "أنشئ حسابك لحفظ تفضيلاتك ومتابعاتك المفضلة." : "سجل دخولك لمزامنة أنديتك وتفضيلاتك عبر الأجهزة.")
                    .font(E360Font.body(14, weight: .medium))
                    .foregroundStyle(E360Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 4)

            // Glassmorphic Login Card
            VStack(spacing: 18) {
                if !errorMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(E360Font.body(13, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
                    .transition(.opacity)
                }

                // Email Field
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(E360Color.accent)
                        .frame(width: 22)

                    TextField("", text: $loginEmail, prompt: Text("البريد الإلكتروني").foregroundStyle(E360Color.textTertiary))
                        .font(E360Font.body(15, weight: .medium))
                        .foregroundStyle(E360Color.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .multilineTextAlignment(.trailing)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [E360Color.accent.opacity(0.3), E360Color.primary.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

                // Password Field
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(E360Color.primary)
                        .frame(width: 22)

                    Group {
                        if showPassword {
                            TextField("", text: $loginPassword, prompt: Text("كلمة المرور").foregroundStyle(E360Color.textTertiary))
                        } else {
                            SecureField("", text: $loginPassword, prompt: Text("كلمة المرور").foregroundStyle(E360Color.textTertiary))
                        }
                    }
                    .font(E360Font.body(15, weight: .medium))
                    .foregroundStyle(E360Color.textPrimary)
                    .multilineTextAlignment(.trailing)

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(E360Color.textTertiary)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [E360Color.primary.opacity(0.3), E360Color.accent.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

                // Action Button (Signup/Login)
                Button {
                    handleAuthAction()
                } label: {
                    ZStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isRegisterMode ? "إنشاء حساب جديد ✨" : "تسجيل الدخول 🔐")
                                .font(E360Font.display(16, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [E360Color.primary, E360Color.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: E360Color.primary.opacity(0.35), radius: 12, y: 4)
                }
                .disabled(isLoading)

                // Toggle Mode Button
                Button {
                    HapticManager.shared.triggerSelection()
                    withAnimation {
                        isRegisterMode.toggle()
                        errorMessage = ""
                    }
                } label: {
                    Text(isRegisterMode ? "لديك حساب بالفعل؟ سجل دخولك" : "ليس لديك حساب؟ أنشئ حساباً جديداً")
                        .font(E360Font.body(13, weight: .bold))
                        .foregroundStyle(E360Color.accent)
                }
                .padding(.top, 4)

                // Divider
                HStack {
                    Rectangle().fill(E360Color.divider).frame(height: 1)
                    Text("أو")
                        .font(E360Font.body(12, weight: .medium))
                        .foregroundStyle(E360Color.textTertiary)
                        .layoutPriority(1)
                    Rectangle().fill(E360Color.divider).frame(height: 1)
                }

                // Apple/Google Social Buttons
                HStack(spacing: 16) {
                    socialLoginButton(icon: "apple.logo", label: "Apple", isEnabled: true) {
                        HapticManager.shared.triggerSelection()
                        socialProviderName = "Apple"
                        showSocialLoginAlert = true
                    }
                    socialLoginButton(icon: "g.circle.fill", label: "Google", isEnabled: true) {
                        HapticManager.shared.triggerSelection()
                        socialProviderName = "Google"
                        showSocialLoginAlert = true
                    }
                }
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.04),
                                E360Color.accent.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: E360Color.primary.opacity(0.08), radius: 30, y: 10)
            .padding(.horizontal, 24)

            // Continue as guest
            Button {
                advanceFromLogin()
            } label: {
                Text("تخطي خطوة الحساب والمتابعة كضيف")
                    .font(E360Font.body(14, weight: .bold))
                    .foregroundStyle(E360Color.accent)
            }
            .padding(.top, 4)

            Spacer()
        }
    }

    private func handleAuthAction() {
        guard !loginEmail.isEmpty && loginEmail.contains("@") else {
            errorMessage = "يرجى إدخال بريد إلكتروني صالح"
            return
        }
        guard loginPassword.count >= 6 else {
            errorMessage = "يجب أن تكون كلمة المرور ٦ خانات على الأقل"
            return
        }
        
        isLoading = true
        errorMessage = ""
        HapticManager.shared.triggerSelection()
        
        Task {
            do {
                if isRegisterMode {
                    try await authService.signup(email: loginEmail, password: loginPassword)
                } else {
                    try await authService.login(email: loginEmail, password: loginPassword)
                }
                
                await MainActor.run {
                    isLoading = false
                    advanceFromLogin()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    HapticManager.shared.triggerNotification(type: .error)
                }
            }
        }
    }

    private func socialLoginButton(
        icon: String,
        label: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(E360Font.body(14, weight: .bold))
            }
            .foregroundStyle(E360Color.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(E360Color.divider, lineWidth: 1)
            )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.45)
    }

    private func advanceFromLogin() {
        HapticManager.shared.triggerImpact(style: .light)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
            currentStep = 2
        }
    }

    // MARK: - Step 3: Game Selection

    private var gamesStep: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("اختر ألعابك المفضلة 🎮")
                    .font(E360Font.hero(26, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)

                Text("سنقوم بتخصيص تغذية المباريات بناءً على اختيارك")
                    .font(E360Font.body(13, weight: .medium))
                    .foregroundStyle(E360Color.textSecondary)
            }
            .padding(.horizontal, 24)

            ScrollView(.vertical, showsIndicators: false) {
                let games = EsportsGame.allCases.filter { $0 != .unknown }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(games) { game in
                        let isSelected = selectedGames.contains(game)

                        Button {
                            HapticManager.shared.triggerImpact(style: .light)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                if isSelected {
                                    selectedGames.remove(game)
                                } else {
                                    selectedGames.insert(game)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    GameIconView(game: game, size: 34)

                                    Text(game.shortName)
                                        .font(E360Font.mono(11, weight: .black))
                                        .foregroundStyle(isSelected ? .white : game.themeColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isSelected ? game.themeColor : game.themeColor.opacity(0.12), in: Capsule())

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(game.themeColor)
                                            .font(.system(size: 20))
                                    }
                                }

                                Text(game.displayName)
                                    .font(E360Font.body(14, weight: .black))
                                    .foregroundStyle(E360Color.textPrimary)
                                    .lineLimit(1)
                            }
                            .padding(14)
                            .frame(height: 98, alignment: .leading)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(game.themeColor.opacity(0.08))
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(isSelected ? game.themeColor.opacity(0.50) : E360Color.divider, lineWidth: 1.5)
                            )
                            .shadow(color: isSelected ? game.themeColor.opacity(0.18) : Color.clear, radius: 12)
                            .scaleEffect(isSelected ? 1.03 : 1.0)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Step 4: Team Follow

    private var teamsStep: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("تابع أنديتك المفضلة ⚔️")
                    .font(E360Font.hero(26, weight: .black))
                    .foregroundStyle(E360Color.textPrimary)

                Text("احصل على إشعارات فورية بمواعيد مبارياتهم")
                    .font(E360Font.body(13, weight: .medium))
                    .foregroundStyle(E360Color.textSecondary)
            }
            .padding(.horizontal, 24)

            ScrollView(.vertical, showsIndicators: false) {
                let onboardingTeams = [
                    MockEsportsData.teamFalcons,
                    MockEsportsData.twistedMinds,
                    MockEsportsData.nasr,
                    MockEsportsData.g2,
                    MockEsportsData.teamProfile(id: MockEsportsData.vitality.id)?.team ?? MockEsportsData.vitality,
                    MockEsportsData.teamProfile(id: MockEsportsData.liquid.id)?.team ?? MockEsportsData.liquid
                ]

                VStack(spacing: 12) {
                    ForEach(onboardingTeams, id: \.id) { team in
                        let isSelected = selectedTeams.contains(team.name)
                        let isSaudi = ["Team Falcons", "Twisted Minds", "Nasr Esports", "Nasr"].contains(team.name)
                        let saudiColor = Color(hex: 0x00a15c)
                        let themeColor = isSaudi ? saudiColor : E360Color.primary

                        Button {
                            HapticManager.shared.triggerImpact(style: .medium)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                if isSelected {
                                    selectedTeams.remove(team.name)
                                } else {
                                    selectedTeams.insert(team.name)
                                }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                TeamAvatar(team: team, size: 50)
                                    .overlay(
                                        Circle().stroke(isSelected ? themeColor.opacity(0.55) : E360Color.divider, lineWidth: 1.5)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(team.displayName)
                                            .font(E360Font.body(15, weight: .bold))
                                            .foregroundStyle(E360Color.textPrimary)

                                        if isSaudi {
                                            Text("🇸🇦")
                                                .font(.system(size: 14))
                                        }
                                    }

                                    if let acronym = team.acronym, acronym.isEmpty == false {
                                        Text(acronym)
                                            .font(E360Font.mono(11, weight: .semibold))
                                            .foregroundStyle(E360Color.textSecondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: isSelected ? "bell.fill" : "bell")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(isSelected ? themeColor : E360Color.textTertiary)
                                    .frame(width: 36, height: 36)
                                    .background(isSelected ? themeColor.opacity(0.14) : Color.clear, in: Circle())
                                    .overlay(Circle().stroke(isSelected ? themeColor.opacity(0.3) : E360Color.divider, lineWidth: 1))
                            }
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(isSelected ? themeColor.opacity(0.45) : E360Color.divider, lineWidth: 1.5)
                            )
                            .shadow(color: isSelected ? themeColor.opacity(0.10) : Color.clear, radius: 10)
                            .scaleEffect(isSelected ? 1.015 : 1.0)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 18) {
            // Page Indicators
            HStack(spacing: 8) {
                ForEach(0..<stepsCount, id: \.self) { index in
                    Capsule()
                        .fill(currentStep == index ? E360Color.accent : E360Color.textTertiary)
                        .frame(width: currentStep == index ? 24 : 8, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
            .padding(.top, 8)

            // Primary Action Button
            Button {
                HapticManager.shared.triggerSelection()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
                    if currentStep < stepsCount - 1 {
                        currentStep += 1
                    } else {
                        completeOnboarding()
                    }
                }
            } label: {
                Text(currentStep == stepsCount - 1 ? "دخول إلى عالم التنافس 🏆" : "التالي")
                    .font(E360Font.display(16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: buttonGradients,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: buttonGradients.first!.opacity(0.40), radius: 14, y: 5)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [.clear, Color(hex: 0x080710).opacity(0.9), Color(hex: 0x080710)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var buttonGradients: [Color] {
        switch currentStep {
        case 1:
            return [E360Color.accent, E360Color.primary]
        case 2:
            let leadColor = selectedGames.first?.themeColor ?? E360Color.accent
            return [leadColor, E360Color.accent]
        case 3:
            return [Color(hex: 0x00a15c), E360Color.accent]
        default:
            return [E360Color.primary, E360Color.accent]
        }
    }

    private func completeOnboarding() {
        saveUserPreferences()
        
        // Sync with backend if logged in
        if UserAuthService.shared.isLoggedIn {
            Task {
                // 1. Sync followed games
                for game in selectedGames {
                    await UserAuthService.shared.follow(entityType: "game", entityId: game.rawValue)
                }
                
                // 2. Sync followed teams
                for teamName in selectedTeams {
                    await UserAuthService.shared.follow(entityType: "team", entityId: teamName)
                }
            }
        }
        
        HapticManager.shared.triggerNotification(type: .success)
        withAnimation {
            hasCompletedOnboarding = true
        }
    }

    private func saveUserPreferences() {
        let gameStrings = selectedGames.map { $0.rawValue }
        UserDefaults.standard.set(gameStrings, forKey: "user.favoriteGames")

        let followedList = Array(selectedTeams)
        UserDefaults.standard.set(followedList, forKey: "user.followedTeams")
    }
}

// MARK: - Floating Particles Effect

private struct OnboardingParticlesView: View {
    @State private var particles: [Particle] = (0..<18).map { _ in Particle() }
    @State private var animationTrigger = false

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color.opacity(animationTrigger ? particle.opacity : particle.opacity * 0.3))
                    .frame(width: particle.size, height: particle.size)
                    .blur(radius: particle.blur)
                    .position(
                        x: animationTrigger ? particle.endX * geo.size.width : particle.startX * geo.size.width,
                        y: animationTrigger ? particle.endY * geo.size.height : particle.startY * geo.size.height
                    )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                animationTrigger = true
            }
        }
    }
}

private struct Particle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let size: CGFloat
    let opacity: Double
    let blur: CGFloat
    let color: Color

    init() {
        startX = CGFloat.random(in: 0.05...0.95)
        startY = CGFloat.random(in: 0.05...0.95)
        endX = startX + CGFloat.random(in: -0.15...0.15)
        endY = startY + CGFloat.random(in: -0.15...0.15)
        size = CGFloat.random(in: 2...6)
        opacity = Double.random(in: 0.15...0.45)
        blur = CGFloat.random(in: 0.5...2.0)

        let colors: [Color] = [E360Color.accent, E360Color.primary, E360Color.gold, .white]
        color = colors.randomElement()!
    }
}

// MARK: - Pulse Animation Modifier

private struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.08 : 0.95)
            .opacity(isPulsing ? 0.6 : 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - GameIconView (kept for compatibility)

struct GameIconView: View {
    let game: EsportsGame
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(game.themeColor.opacity(0.12))
                .frame(width: size, height: size)
                .overlay(
                    Circle().stroke(game.themeColor.opacity(0.35), lineWidth: 1.5)
                )
                .shadow(color: game.themeColor.opacity(0.3), radius: 6)

            Image(systemName: systemImageName)
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [game.themeColor, game.themeColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var systemImageName: String {
        switch game {
        case .leagueOfLegends:
            return "crown.fill"
        case .counterStrike:
            return "target"
        case .valorant:
            return "bolt.fill"
        case .dota2:
            return "shield.fill"
        case .rocketLeague:
            return "car.fill"
        case .overwatch:
            return "shield.hexagonpath.fill"
        case .rainbowSix:
            return "exclamationmark.shield.fill"
        case .eaSportsFC:
            return "soccerball"
        case .starcraft2:
            return "globe.desk.fill"
        case .callOfDuty:
            return "skull.fill"
        case .kingOfGlory:
            return "sword.and.shield.fill"
        case .wildRift:
            return "sparkles"
        default:
            return "gamecontroller.fill"
        }
    }
}
