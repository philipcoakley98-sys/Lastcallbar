import Foundation

/// Lightweight REST client for the existing LAST CALL Supabase project.
/// Uses only the public/publishable browser key; no service-role secret belongs in the app.
final class LastCallAPI {
    static let shared = LastCallAPI()

    private let baseURL = URL(string: "https://ccqyreaanjhfhglmmgkn.supabase.co")!
    private let publishableKey = "sb_publishable_LHWzWXPoDCD0VBl1i6QeBg_uFXrS_yL"

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
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,title,body,category,city,country,anonymous_name,created_at"),
            URLQueryItem(name: "status", value: "eq.published"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "30")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        return try JSONDecoder.lastCall.decode([RemoteStory].self, from: data)
    }

    func signUp(email: String, password: String, displayName: String?) async throws -> AuthResponse {
        let payload = AuthPayload(email: email, password: password, data: displayName.map { ["display_name": $0] })
        let data = try JSONEncoder.lastCall.encode(payload)
        let request = request(path: "auth/v1/signup", method: "POST", body: data)
        let (responseData, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: responseData)
        return try JSONDecoder.lastCall.decode(AuthResponse.self, from: responseData)
    }

    func signIn(email: String, password: String) async throws -> AuthResponse {
        let payload = AuthPayload(email: email, password: password, data: nil)
        let data = try JSONEncoder.lastCall.encode(payload)
        let request = request(path: "auth/v1/token?grant_type=password", method: "POST", body: data)
        let (responseData, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: responseData)
        return try JSONDecoder.lastCall.decode(AuthResponse.self, from: responseData)
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "LAST CALL could not complete that request."
            throw LastCallAPIError.server(message)
        }
    }
}

struct RemoteStory: Decodable, Identifiable {
    let id: UUID
    let title: String
    let body: String
    let category: String
    let city: String?
    let country: String?
    let anonymous_name: String?
    let created_at: String

    var location: String {
        [city, country].compactMap { $0 }.joined(separator: ", ")
    }
}

struct AuthPayload: Encodable {
    let email: String
    let password: String
    let data: [String: String]?
}

struct AuthResponse: Decodable {
    let access_token: String?
    let refresh_token: String?
    let user: AuthUser?
}

struct AuthUser: Decodable {
    let id: UUID
    let email: String?
}

enum LastCallAPIError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        }
    }
}

extension JSONDecoder {
    static var lastCall: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var lastCall: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        return encoder
    }
}
