from pathlib import Path

root = Path("ios/LastCall")
api = root / "SupabaseAPI.swift"
text = api.read_text()
start = text.index("func fetchCommentCounts")
end = text.index("func toggleBeerReaction", start)
replacement = '''func fetchCommentCounts(storyIDs: [UUID], accessToken: String?) async throws -> [UUID: Int] {
    guard !storyIDs.isEmpty else { return [:] }
    var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/comments"), resolvingAgainstBaseURL: false)!
    components.queryItems = [
        URLQueryItem(name: "select", value: "story_id"),
        URLQueryItem(name: "story_id", value: "in.(\\(storyIDs.map(\\.uuidString).joined(separator: ",")))"),
        URLQueryItem(name: "limit", value: "1000")
    ]
    var request = URLRequest(url: components.url!)
    request.setValue(publishableKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \\(accessToken ?? publishableKey)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    try validate(response, data: data)
    let rows = try JSONDecoder.lastCall.decode([CommentCountRow].self, from: data)
    return rows.reduce(into: [UUID: Int]()) { counts, row in
        counts[row.storyId, default: 0] += 1
    }
}
'''
api.write_text(text[:start] + replacement + text[end:])

for path in root.rglob("*.swift"):
    path.write_text(path.read_text().replace("+ =", "+="))
