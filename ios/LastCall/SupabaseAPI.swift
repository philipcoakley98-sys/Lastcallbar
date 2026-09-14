import Foundation
import Security

/// Lightweight REST client for the existing LAST CALL Supabase project.
/// Only the public/publishable key is embedded in the app.
final class LastCallAPI {
    static let shared = LastCallAPI()
    private let baseURL = URL(string: "https://ccqyreaanjhfhglmmgkn.supabase.co")!
    private let publishableKey = "sb_publishable_LHWzWXPoDCD0VBl1i6QeBg_uFXrS_yL"
    private let keychainService = "com.lastcall.app.session"
    private let keychainAccount = "supabase"
    private init() {}

    private func request(path: String, method: String = "GET", body: Data? = nil, accessToken: String? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        request.httpBody = body
        return request
    }

    func fetchPublishedStories() async throws -> [RemoteStory] {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/stories"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: "id,author_id,title,body,category,city,country,anonymous_name,created_at"), URLQueryItem(name: "status", value: "eq.published"), URLQueryItem(name: "order", value: "created_at.desc"), URLQueryItem(name: "limit", value: "30")]
        var request = URLRequest(url: components.url!)
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        return try JSONDecoder.lastCall.decode([RemoteStory].self, from: data)
    }

    func fetchReactionStoryIDs(userID: UUID, accessToken: String) async throws -> Set<UUID> {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/reactions"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: "story_id"), URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"), URLQueryItem(name: "kind", value: "eq.beer")]
        var request = URLRequest(url: components.url!)
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        return Set(try JSONDecoder.lastCall.decode([ReactionRow].self, from: data).map(\.storyId))
    }

    func toggleBeerReaction(storyID: UUID, userID: UUID, accessToken: String, reacted: Bool) async throws -> Bool {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/reactions"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "story_id", value: "eq.\(storyID.uuidString)"), URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"), URLQueryItem(name: "kind", value: "eq.beer")]
        var request: URLRequest
        if reacted {
            request = URLRequest(url: components.url!)
            request.httpMethod = "DELETE"
            request.setValue(publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request = self.request(path: "rest/v1/reactions", method: "POST", body: try JSONEncoder.lastCall.encode(ReactionInsert(storyId: storyID, userId: userID, kind: "beer")), accessToken: accessToken)
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        return !reacted
    }

    func signUp(email: String, password: String, displayName: String?) async throws -> AuthResponse {
        let payload = AuthPayload(email: email, password: password, data: displayName.map { ["display_name": $0] })
        let request = self.request(path: "auth/v1/signup", method: "POST", body: try JSONEncoder.lastCall.encode(payload))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        let auth = try JSONDecoder.lastCall.decode(AuthResponse.self, from: data)
        persist(auth)
        return auth
    }

    func signIn(email: String, password: String) async throws -> AuthResponse {
        let payload = AuthPayload(email: email, password: password, data: nil)
        let request = self.request(path: "auth/v1/token?grant_type=password", method: "POST", body: try JSONEncoder.lastCall.encode(payload))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        let auth = try JSONDecoder.lastCall.decode(AuthResponse.self, from: data)
        persist(auth)
        return auth
    }

    func restoreSession() async -> AuthResponse? {
        guard let refreshToken = keychainGet() else { return nil }
        do {
            let request = self.request(path: "auth/v1/token?grant_type=refresh_token", method: "POST", body: try JSONEncoder.lastCall.encode(RefreshPayload(refreshToken: refreshToken)))
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response, data: data)
            let auth = try JSONDecoder.lastCall.decode(AuthResponse.self, from: data)
            persist(auth)
            return auth
        } catch { clearSession(); return nil }
    }

    func signOut() { clearSession() }

    func insertStory(title: String, body: String, category: String, city: String?, country: String?, anonymous: Bool, accessToken: String, userID: UUID) async throws {
        let payload = StoryInsert(authorId: userID, title: title.isEmpty ? "Untitled story" : title, body: body, category: category, city: city?.nilIfEmpty, country: country?.nilIfEmpty, anonymousName: anonymous ? "Anonymous" : nil, status: "pending")
        var request = self.request(path: "rest/v1/stories", method: "POST", body: try JSONEncoder.lastCall.encode(payload), accessToken: accessToken)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
    }

    func fetchProfile(userID: UUID, accessToken: String) async throws -> ProfileRow? {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/profiles"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: "id,display_name,username,bio,avatar_url,is_anonymous,privacy_followers,privacy_messages"), URLQueryItem(name: "id", value: "eq.\(userID.uuidString)"), URLQueryItem(name: "limit", value: "1")]
        var request = URLRequest(url: components.url!); request.setValue(publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data)
        return try JSONDecoder.lastCall.decode([ProfileRow].self, from: data).first
    }

    func fetchProfiles(excluding userID: UUID?, accessToken: String) async throws -> [ProfileRow] {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/profiles"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "select", value: "id,display_name,username,bio,avatar_url,is_anonymous,privacy_followers,privacy_messages"), URLQueryItem(name: "order", value: "created_at.desc"), URLQueryItem(name: "limit", value: "40")]
        if let userID { items.append(URLQueryItem(name: "id", value: "neq.\(userID.uuidString)")) }
        components.queryItems = items
        var request = URLRequest(url: components.url!); request.setValue(publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data)
        return try JSONDecoder.lastCall.decode([ProfileRow].self, from: data)
    }

    func fetchProfiles(ids: [UUID], accessToken: String) async throws -> [ProfileRow] {
        guard !ids.isEmpty else { return [] }
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/profiles"), resolvingAgainstBaseURL: false)!
        let values = ids.map(\.uuidString).joined(separator: ",")
        components.queryItems = [URLQueryItem(name: "select", value: "id,display_name,username,bio,avatar_url,is_anonymous,privacy_followers,privacy_messages"), URLQueryItem(name: "id", value: "in.(\(values))"), URLQueryItem(name: "limit", value: "40")]
        var request = URLRequest(url: components.url!); request.setValue(publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data)
        return try JSONDecoder.lastCall.decode([ProfileRow].self, from: data)
    }

    func fetchFollowing(userID: UUID, accessToken: String) async throws -> Set<UUID> {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/follows"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: "following_id"), URLQueryItem(name: "follower_id", value: "eq.\(userID.uuidString)")]
        var request = URLRequest(url: components.url!); request.setValue(publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data)
        return Set(try JSONDecoder.lastCall.decode([FollowRow].self, from: data).map(\.followingId))
    }

    func toggleFollow(targetID: UUID, userID: UUID, accessToken: String, following: Bool) async throws -> Bool {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/follows"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "follower_id", value: "eq.\(userID.uuidString)"), URLQueryItem(name: "following_id", value: "eq.\(targetID.uuidString)")]
        var request: URLRequest
        if following { request = URLRequest(url: components.url!); request.httpMethod = "DELETE"; request.setValue(publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        else { request = self.request(path: "rest/v1/follows", method: "POST", body: try JSONEncoder.lastCall.encode(FollowInsert(followerId: userID, followingId: targetID)), accessToken: accessToken); request.setValue("return=minimal", forHTTPHeaderField: "Prefer") }
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data); return !following
    }

    func startConversation(targetID: UUID, accessToken: String) async throws -> UUID {
        let body = try JSONEncoder.lastCall.encode(["target_user": targetID.uuidString])
        let request = self.request(path: "rest/v1/rpc/start_conversation", method: "POST", body: body, accessToken: accessToken)
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data); return try JSONDecoder.lastCall.decode(UUID.self, from: data)
    }

    func fetchConversations(userID: UUID, accessToken: String) async throws -> [ConversationRow] {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/conversation_members"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: "conversation_id,status"), URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"), URLQueryItem(name: "order", value: "joined_at.desc")]
        var request = URLRequest(url: components.url!); request.setValue(publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data)
        let memberships = try JSONDecoder.lastCall.decode([MembershipRow].self, from: data)
        var result: [ConversationRow] = []
        for membership in memberships { let members = try await fetchOtherMember(conversationID: membership.conversationId, userID: userID, accessToken: accessToken); guard let other = members.first, let otherUserID = other.userId, let profile = try await fetchProfile(userID: otherUserID, accessToken: accessToken) else { continue }; let latest = try await fetchLatestMessage(conversationID: membership.conversationId, accessToken: accessToken); result.append(ConversationRow(id: membership.conversationId, status: membership.status, otherUser: profile, latestMessage: latest)) }
        return result
    }

    func fetchMessages(conversationID: UUID, accessToken: String) async throws -> [MessageRow] {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: "id,conversation_id,sender_id,body,created_at,read_at"), URLQueryItem(name: "conversation_id", value: "eq.\(conversationID.uuidString)"), URLQueryItem(name: "order", value: "created_at.asc"), URLQueryItem(name: "limit", value: "200")]
        var request = URLRequest(url: components.url!); request.setValue(publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data); return try JSONDecoder.lastCall.decode([MessageRow].self, from: data)
    }

    func sendMessage(conversationID: UUID, senderID: UUID, body: String, accessToken: String) async throws {
        let request = self.request(path: "rest/v1/messages", method: "POST", body: try JSONEncoder.lastCall.encode(MessageInsert(conversationId: conversationID, senderId: senderID, body: body)), accessToken: accessToken)
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data)
    }

    func respondToMessageRequest(conversationID: UUID, decision: String, accessToken: String) async throws {
        let body = try JSONEncoder.lastCall.encode(["cid": conversationID.uuidString, "decision": decision])
        let request = self.request(path: "rest/v1/rpc/respond_to_message_request", method: "POST", body: body, accessToken: accessToken)
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data)
    }

    func fetchNotifications(userID: UUID, accessToken: String) async throws -> [NotificationRow] {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/notifications"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: "id,type,actor_id,story_id,conversation_id,read_at,created_at"), URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"), URLQueryItem(name: "order", value: "created_at.desc"), URLQueryItem(name: "limit", value: "50")]
        var request = URLRequest(url: components.url!); request.setValue(publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data); return try JSONDecoder.lastCall.decode([NotificationRow].self, from: data)
    }

    func markNotificationsRead(userID: UUID, accessToken: String) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/notifications"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"), URLQueryItem(name: "read_at", value: "is.null")]
        var request = URLRequest(url: components.url!); request.httpMethod = "PATCH"; request.setValue(publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue("return=minimal", forHTTPHeaderField: "Prefer"); request.httpBody = try JSONEncoder.lastCall.encode(["read_at": ISO8601DateFormatter().string(from: Date())])
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data)
    }

    private func fetchOtherMember(conversationID: UUID, userID: UUID, accessToken: String) async throws -> [MembershipRow] {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/conversation_members"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: "user_id,status"), URLQueryItem(name: "conversation_id", value: "eq.\(conversationID.uuidString)"), URLQueryItem(name: "user_id", value: "neq.\(userID.uuidString)"), URLQueryItem(name: "limit", value: "1")]
        var request = URLRequest(url: components.url!); request.setValue(publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data); return try JSONDecoder.lastCall.decode([MembershipRow].self, from: data)
    }

    private func fetchLatestMessage(conversationID: UUID, accessToken: String) async throws -> MessageRow? {
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "select", value: "id,conversation_id,sender_id,body,created_at,read_at"), URLQueryItem(name: "conversation_id", value: "eq.\(conversationID.uuidString)"), URLQueryItem(name: "order", value: "created_at.desc"), URLQueryItem(name: "limit", value: "1")]
        var request = URLRequest(url: components.url!); request.setValue(publishableKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization"); let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data); return try JSONDecoder.lastCall.decode([MessageRow].self, from: data).first
    }

    private func persist(_ auth: AuthResponse) { if let refreshToken = auth.refreshToken { keychainSet(refreshToken) } }
    private func keychainSet(_ value: String) { let data = Data(value.utf8); let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: keychainAccount]; SecItemDelete(query as CFDictionary); SecItemAdd(query.merging([kSecValueData as String: data]) { _, new in new } as CFDictionary, nil) }
    private func keychainGet() -> String? { let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: keychainAccount, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]; var result: AnyObject?; guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }; return String(data: data, encoding: .utf8) }
    private func clearSession() { let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: keychainAccount]; SecItemDelete(query as CFDictionary) }
    private func validate(_ response: URLResponse, data: Data) throws { guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw LastCallAPIError.server(String(data: data, encoding: .utf8) ?? "LAST CALL could not complete that request.") } }
}

struct RemoteStory: Decodable, Identifiable { let id: UUID; let authorId: UUID?; let title: String; let body: String; let category: String; let city: String?; let country: String?; let anonymousName: String?; let createdAt: String; var location: String { [city, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ") } }
struct ReactionRow: Decodable { let storyId: UUID }
struct ReactionInsert: Encodable { let storyId: UUID; let userId: UUID; let kind: String }
struct StoryInsert: Encodable { let authorId: UUID; let title: String; let body: String; let category: String; let city: String?; let country: String?; let anonymousName: String?; let status: String }
struct FollowRow: Decodable { let followingId: UUID }
struct FollowInsert: Encodable { let followerId: UUID; let followingId: UUID }
struct ProfileRow: Decodable, Identifiable { let id: UUID; let displayName: String?; let username: String?; let bio: String?; let avatarURL: String?; let isAnonymous: Bool; let privacyFollowers: String; let privacyMessages: String; var publicName: String { isAnonymous ? (username ?? "LAST CALL member") : (displayName ?? username ?? "LAST CALL member") } }
struct MembershipRow: Decodable { let conversationId: UUID; let userId: UUID?; let status: String }
struct ConversationRow: Identifiable { let id: UUID; let status: String; let otherUser: ProfileRow; let latestMessage: MessageRow? }
struct MessageRow: Decodable, Identifiable { let id: UUID; let conversationId: UUID; let senderId: UUID; let body: String; let createdAt: String; let readAt: String? }
struct MessageInsert: Encodable { let conversationId: UUID; let senderId: UUID; let body: String }
struct NotificationRow: Decodable, Identifiable { let id: UUID; let type: String; let actorId: UUID?; let storyId: UUID?; let conversationId: UUID?; let readAt: String?; let createdAt: String }
struct AuthPayload: Encodable { let email: String; let password: String; let data: [String: String]? }
struct RefreshPayload: Encodable { let refreshToken: String }
struct AuthResponse: Decodable { let accessToken: String?; let refreshToken: String?; let user: AuthUser? }
struct AuthUser: Decodable { let id: UUID; let email: String? }

enum LastCallAPIError: LocalizedError { case server(String); var errorDescription: String? { if case .server(let message) = self { return message }; return nil } }
extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
extension JSONDecoder { static var lastCall: JSONDecoder { let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; return decoder } }
extension JSONEncoder { static var lastCall: JSONEncoder { let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase; return encoder } }