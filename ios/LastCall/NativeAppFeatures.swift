import Foundation

extension LastCallAPI {
  private var nativeBaseURL: URL { URL(string: "https://ccqyreaanjhfhglmmgkn.supabase.co")! }
  private var nativePublishableKey: String { "sb_publishable_LHWzWXPoDCD0VBl1i6QeBg_uFXrS_yL" }

  func fetchReactionCounts(storyIDs: [UUID], accessToken: String) async throws -> [UUID: Int] {
    guard !storyIDs.isEmpty else { return [:] }
    var components = URLComponents(
      url: nativeBaseURL.appendingPathComponent("rest/v1/reactions"), resolvingAgainstBaseURL: false
    )!
    components.queryItems = [
      URLQueryItem(name: "select", value: "story_id"),
      URLQueryItem(name: "kind", value: "eq.beer"),
      URLQueryItem(
        name: "story_id", value: "in.(\(storyIDs.map(\.uuidString).joined(separator: ",")))"),
    ]
    var request = URLRequest(url: components.url!)
    request.setValue(nativePublishableKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      return [:]
    }
    struct Row: Decodable { let storyId: UUID }
    let rows = try JSONDecoder.lastCall.decode([Row].self, from: data)
    return Dictionary(grouping: rows, by: \.storyId).mapValues(\.count)
  }

  func markMessageRead(messageID: UUID, accessToken: String) async throws {
    let body = try JSONEncoder.lastCall.encode(["message_id": messageID.uuidString])
    var request = URLRequest(
      url: nativeBaseURL.appendingPathComponent("rest/v1/rpc/mark_message_read"))
    request.httpMethod = "POST"
    request.setValue(nativePublishableKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      throw LastCallAPIError.server(
        String(data: data, encoding: .utf8) ?? "Message could not be marked read.")
    }
  }

  func blockUser(userID: UUID, accessToken: String) async throws {
    let body = try JSONEncoder.lastCall.encode(["target_user": userID.uuidString])
    var request = URLRequest(url: nativeBaseURL.appendingPathComponent("rest/v1/rpc/block_user"))
    request.httpMethod = "POST"
    request.setValue(nativePublishableKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      throw LastCallAPIError.server(
        String(data: data, encoding: .utf8) ?? "That member could not be blocked.")
    }
  }
}
