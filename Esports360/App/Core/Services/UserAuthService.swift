import Foundation
import Combine
import SwiftUI
import OSLog

class UserAuthService: ObservableObject {
    static let shared = UserAuthService()
    private static let logger = Logger(subsystem: "com.esports360", category: "UserAuthService")

    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var preferences = UserPreferences.default
    @Published var followedEntities: [UserFollow] = []

    private var baseURL: URL {
        let stored = UserDefaults.standard.string(forKey: AppStorageKeys.backendBaseURL)
        let rawUrl = (stored != nil && stored!.isEmpty == false) ? stored! : E360Constants.defaultBackendBaseURL
        return URL(string: rawUrl) ?? URL(string: E360Constants.defaultBackendBaseURL)!
    }

    private init() {
        self.isLoggedIn = KeychainManager.shared.getToken() != nil
        if isLoggedIn {
            Task { await fetchProfileAndPreferences() }
        }
    }

    func fetchProfileAndPreferences() async {
        guard let token = KeychainManager.shared.getToken() else { return }

        do {
            // 1. Profile
            let profileUrl = baseURL.appendingPathComponent("v1/user/profile")
            var profileRequest = URLRequest(url: profileUrl)
            profileRequest.httpMethod = "GET"
            profileRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (profileData, profileResponse) = try await URLSession.shared.data(for: profileRequest)
            if let httpRes = profileResponse as? HTTPURLResponse, httpRes.statusCode == 200 {
                struct ProfileWrapper: Codable { let user: User }
                let decoded = try JSONDecoder.pandaScore.decode(ProfileWrapper.self, from: profileData)
                await MainActor.run { self.currentUser = decoded.user; self.isLoggedIn = true }
            } else {
                await logout(); return
            }

            // 2. Preferences
            let prefsUrl = baseURL.appendingPathComponent("v1/user/preferences")
            var prefsRequest = URLRequest(url: prefsUrl)
            prefsRequest.httpMethod = "GET"
            prefsRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (prefsData, prefsResponse) = try await URLSession.shared.data(for: prefsRequest)
            if let httpRes = prefsResponse as? HTTPURLResponse, httpRes.statusCode == 200 {
                struct PrefsWrapper: Codable { let preferences: UserPreferences }
                let decoded = try JSONDecoder.pandaScore.decode(PrefsWrapper.self, from: prefsData)
                await MainActor.run { self.preferences = decoded.preferences }
            }

            // 3. Follows
            let followsUrl = baseURL.appendingPathComponent("v1/user/follows")
            var followsRequest = URLRequest(url: followsUrl)
            followsRequest.httpMethod = "GET"
            followsRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (followsData, followsResponse) = try await URLSession.shared.data(for: followsRequest)
            if let httpRes = followsResponse as? HTTPURLResponse, httpRes.statusCode == 200 {
                struct FollowsWrapper: Codable { let follows: [UserFollow] }
                let decoded = try JSONDecoder.pandaScore.decode(FollowsWrapper.self, from: followsData)
                await MainActor.run {
                    self.followedEntities = decoded.follows

                    let followedGames = decoded.follows.filter { $0.entityType == "game" }.compactMap { $0.entityName }
                    let mappedGames = followedGames.map { code -> String in
                        switch code.lowercased() {
                        case "lol", "league-of-legends":          return "league-of-legends"
                        case "cs2", "cs-go", "counter-strike":   return "cs-go"
                        case "valorant":                          return "valorant"
                        case "dota2", "dota-2":                   return "dota-2"
                        case "rocket-league":                     return "rocket-league"
                        case "overwatch", "overwatch-2":          return "overwatch"
                        case "rainbow-six-siege", "rainbow-6-siege": return "rainbow-6-siege"
                        case "ea-fc", "ea-sports-fc":             return "ea-sports-fc"
                        case "starcraft-2":                       return "starcraft-2"
                        case "call-of-duty":                      return "call-of-duty"
                        case "king-of-glory":                     return "king-of-glory"
                        case "wild-rift":                         return "wild-rift"
                        default: return code
                        }
                    }
                    UserDefaults.standard.set(mappedGames, forKey: AppStorageKeys.favoriteGames)

                    let followedTeams = decoded.follows.filter { $0.entityType == "team" }.compactMap { $0.entityName }
                    UserDefaults.standard.set(followedTeams, forKey: AppStorageKeys.followedTeams)
                }
            }
        } catch {
            Self.logger.error("fetchProfileAndPreferences failed: \(error, privacy: .public)")
        }
    }

    func signup(email: String, password: String) async throws {
        let url = baseURL.appendingPathComponent("v1/auth/signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthService", code: 0,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "auth.error.connection", defaultValue: "خطأ في الاتصال بالخادم")])
        }

        if httpRes.statusCode == 200 {
            let authResponse = try JSONDecoder.pandaScore.decode(AuthResponse.self, from: data)
            _ = KeychainManager.shared.saveToken(authResponse.token)
            await MainActor.run { self.currentUser = authResponse.user; self.isLoggedIn = true }
            await fetchProfileAndPreferences()
        } else {
            struct ErrorResponse: Codable { let detail: String }
            let err = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            let msg = err?.detail == "email_already_registered"
                ? String(localized: "auth.error.emailExists",   defaultValue: "هذا البريد الإلكتروني مسجل بالفعل")
                : String(localized: "auth.error.signupFailed",  defaultValue: "فشل التسجيل. يرجى التحقق من البريد وكلمة المرور")
            throw NSError(domain: "AuthService", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    func login(email: String, password: String) async throws {
        let url = baseURL.appendingPathComponent("v1/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthService", code: 0,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "auth.error.connection", defaultValue: "خطأ في الاتصال بالخادم")])
        }

        if httpRes.statusCode == 200 {
            let authResponse = try JSONDecoder.pandaScore.decode(AuthResponse.self, from: data)
            _ = KeychainManager.shared.saveToken(authResponse.token)
            await MainActor.run { self.currentUser = authResponse.user; self.isLoggedIn = true }
            await fetchProfileAndPreferences()
        } else {
            throw NSError(domain: "AuthService", code: httpRes.statusCode,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "auth.error.invalidCredentials",
                    defaultValue: "البريد الإلكتروني أو كلمة المرور غير صحيحة")])
        }
    }

    func syncPreferences(newPrefs: UserPreferences) async {
        guard let token = KeychainManager.shared.getToken() else { return }
        let url = baseURL.appendingPathComponent("v1/user/preferences")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(newPrefs)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                struct PrefsWrapper: Codable { let preferences: UserPreferences }
                let decoded = try JSONDecoder.pandaScore.decode(PrefsWrapper.self, from: data)
                await MainActor.run { self.preferences = decoded.preferences }
            }
        } catch {
            Self.logger.error("syncPreferences failed: \(error, privacy: .public)")
        }
    }

    func follow(entityType: String, entityId: String, notificationLevel: String = "normal") async {
        guard let token = KeychainManager.shared.getToken() else { return }
        let url = baseURL.appendingPathComponent("v1/user/follows")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["entityType": entityType, "entityId": entityId, "notificationLevel": notificationLevel]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                await fetchProfileAndPreferences()
            }
        } catch {
            Self.logger.error("follow(\(entityType),\(entityId)) failed: \(error, privacy: .public)")
        }
    }

    func unfollow(entityType: String, entityId: String) async {
        guard let token = KeychainManager.shared.getToken() else { return }
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("v1/user/follows"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "entityType", value: entityType),
            URLQueryItem(name: "entityId",   value: entityId)
        ]
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                await fetchProfileAndPreferences()
            }
        } catch {
            Self.logger.error("unfollow(\(entityType),\(entityId)) failed: \(error, privacy: .public)")
        }
    }

    func deleteAccount() async throws {
        guard let token = KeychainManager.shared.getToken() else { return }
        let url = baseURL.appendingPathComponent("v1/user/account")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthService", code: 0,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "auth.error.connection", defaultValue: "خطأ في الاتصال بالخادم")])
        }
        if httpRes.statusCode == 200 {
            await logout()
        } else {
            throw NSError(domain: "AuthService", code: httpRes.statusCode,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "auth.error.deleteAccountFailed",
                    defaultValue: "فشل حذف الحساب")])
        }
    }

    func logout() async {
        KeychainManager.shared.deleteToken()
        await MainActor.run {
            self.currentUser = nil
            self.isLoggedIn = false
            self.preferences = UserPreferences.default
            self.followedEntities = []
        }
    }
}
