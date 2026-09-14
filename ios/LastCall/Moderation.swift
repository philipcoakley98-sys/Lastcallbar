import Foundation

extension LastCallAPI {
  func reportUser(
    reporterID: UUID, reportedUserID: UUID, reason: String, details: String?, accessToken: String
  ) async throws {
    let payload = ReportInsert(
      reporterId: reporterID, storyId: nil, reportedUserId: reportedUserID, reason: reason,
      details: details?.nilIfEmpty, status: "open")
    var request = URLRequest(
      url: URL(string: "https://ccqyreaanjhfhglmmgkn.supabase.co/rest/v1/reports")!)
    request.httpMethod = "POST"
    request.setValue("sb_publishable_LHWzWXPoDCD0VBl1i6QeBg_uFXrS_yL", forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("return = minimal", forHTTPHeaderField: "Prefer")
    request.httpBody = try JSONEncoder.lastCall.encode(payload)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      throw LastCallAPIError.server(
        String(data: data, encoding: .utf8) ?? "That report could not be submitted.")
    }
  }
}

private struct ReportInsert: Encodable {
  let reporterId: UUID
  let storyId: UUID?
  let reportedUserId: UUID?
  let reason: String
  let details: String?
  let status: String
}
