import SwiftUI

enum AuthMode { case signIn, signUp }

@main
struct LastCallNativeApp: App {
    @StateObject private var model = NativeAppModel()
    var body: some Scene {
        WindowGroup {
            NativeRootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .task { await model.bootstrap() }
        }
    }
}

@MainActor
final class NativeAppModel: ObservableObject {
    @Published var tab: NativeTab = .home
    @Published var stories: [NativeStory] = NativeStory.samples
    @Published var signedIn = false
    @Published var user: AuthUser?
    @Published var token: String?
    @Published var profile: ProfileRow?
    @Published var unread = 0
    @Published var reactions = Set<UUID>()
    @Published var error: String?
    @Published var authMode: AuthMode = .signIn
    @Published var showAuth = false
    @Published var refreshID = UUID()

    var session: Bool { signedIn && user != nil && token != nil }

    func bootstrap() async {
        if let auth = await LastCallAPI.shared.restoreSession(), let t = auth.accessToken, let u = auth.user {
            token = t; user = u; signedIn = true
            await refreshAccount()
        }
        await refreshStories()
    }

    func refreshStories() async {
        do {
            let remote = try await LastCallAPI.shared.fetchPublishedStories()
            if !remote.isEmpty {
                let ids = remote.map(\.id)
                stories = remote.map { NativeStory(remote: $0) }
                if let uid = user?.id, let t = token {
                    reactions = try await LastCallAPI.shared.fetchReactionStoryIDs(userID: uid, accessToken: t).intersection(ids)
                }
            }
        } catch {
            error = "Stories could not be refreshed just now."
        }
        refreshID = UUID()
    }

    func signIn(email: String, password: String) async {
        do {
            let auth = try await LastCallAPI.shared.signIn(email: email, password: password)
            guard let t = auth.accessToken, let u = auth.user else { throw LastCallAPIError.server("Sign in did not return a session.") }
            token = t; user = u; signedIn = true; showAuth = false
            await refreshAccount()
        } catch { error = cleanError(error) }
    }

    func signUp(email: String, password: String, displayName: String?) async {
        do {
            let auth = try await LastCallAPI.shared.signUp(email: email, password: password, displayName: displayName)
            if let t = auth.accessToken, let u = auth.user {
                token = t; user = u; signedIn = true; showAuth = false
                await refreshAccount()
            } else {
                error = "Account created. Check your email to confirm your address, then sign in to LAST CALL."
            }
        } catch { error = cleanError(error) }
    }

    func signOut() {
        LastCallAPI.shared.signOut()
        token = nil; user = nil; profile = nil; signedIn = false; reactions = []; unread = 0
    }

    func refreshAccount() async {
        guard let token, let userID = user?.id else { return }
        do {
            profile = try await LastCallAPI.shared.fetchProfile(userID: userID, accessToken: token)
            reactions = try await LastCallAPI.shared.fetchReactionStoryIDs(userID: userID, accessToken: token)
            unread = try await LastCallAPI.shared.fetchNotifications(userID: userID, accessToken: token).filter { $0.readAt == nil }.count
        } catch {
            // Keep the authenticated session even if optional account data is unavailable.
        }
    }

    func submitStory(title: String, body: String, category: String, city: String, country: String, anonymous: Bool) async -> Bool {
        guard let token, let userID = user?.id else { authMode = .signIn; showAuth = true; return false }
        do {
            try await LastCallAPI.shared.insertStory(title: title, body: body, category: category, city: city, country: country, anonymous: anonymous, accessToken: token, userID: userID)
            await refreshStories()
            return true
        } catch { error = cleanError(error); return false }
    }

    func toggleReaction(for story: NativeStory) async {
        guard let token, let userID = user?.id else { authMode = .signIn; showAuth = true; return }
        let reacted = reactions.contains(story.id)
        do {
            let newState = try await LastCallAPI.shared.toggleBeerReaction(storyID: story.id, userID: userID, accessToken: token, reacted: reacted)
            if newState { reactions.insert(story.id) } else { reactions.remove(story.id) }
        } catch { error = cleanError(error) }
    }

    private func cleanError(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.contains("Invalid login credentials") { return "That email or password was not recognised." }
        if raw.contains("Email not confirmed") { return "Please confirm your email before signing in." }
        return raw.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
    }
}
