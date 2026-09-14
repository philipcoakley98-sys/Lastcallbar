import SwiftUI

@main
struct LastCallApp: App {
    @StateObject private var model = LastCallModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .task { await model.restoreSessionAndLoad() }
        }
    }
}

@MainActor
final class LastCallModel: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var stories = Story.samples
    @Published var isSignedIn = false
    @Published var user: AuthUser?
    @Published var accessToken: String?
    @Published var profile: ProfileRow?
    @Published var reactedStoryIDs = Set<UUID>()
    @Published var isLoadingStories = false
    @Published var authPresented = false
    @Published var authMode: AuthMode = .signIn
    @Published var errorMessage: String?
    @Published var unreadNotifications = 0
    @Published var refreshID = UUID()

    var hasSession: Bool { isSignedIn && user != nil && accessToken != nil }

    func restoreSessionAndLoad() async {
        if let auth = await LastCallAPI.shared.restoreSession(), let token = auth.accessToken, let signedInUser = auth.user {
            accessToken = token
            user = signedInUser
            isSignedIn = true
            await loadAccountData()
        }
        await loadStories()
    }

    func loadStories() async {
        isLoadingStories = true
        defer { isLoadingStories = false }
        do {
            let remote = try await LastCallAPI.shared.fetchPublishedStories()
            if !remote.isEmpty {
                stories = remote.map(Story.init(remote:))
            }
        } catch {
            errorMessage = "Stories could not be refreshed just now."
        }
        refreshID = UUID()
    }

    func signIn(email: String, password: String) async {
        do {
            let auth = try await LastCallAPI.shared.signIn(email: email, password: password)
            guard let token = auth.accessToken, let signedInUser = auth.user else { throw LastCallAPIError.server("Sign in did not return a session.") }
            accessToken = token
            user = signedInUser
            isSignedIn = true
            authPresented = false
            await loadAccountData()
        } catch { errorMessage = cleanError(error) }
    }

    func signUp(email: String, password: String, displayName: String?) async {
        do {
            let auth = try await LastCallAPI.shared.signUp(email: email, password: password, displayName: displayName)
            if let token = auth.accessToken, let signedInUser = auth.user {
                accessToken = token
                user = signedInUser
                isSignedIn = true
                authPresented = false
                await loadAccountData()
            } else {
                errorMessage = "Account created. Check your email to confirm your address, then sign in to LAST CALL."
            }
        } catch { errorMessage = cleanError(error) }
    }

    func signOut() {
        LastCallAPI.shared.signOut()
        accessToken = nil
        user = nil
        profile = nil
        isSignedIn = false
        reactedStoryIDs = []
        unreadNotifications = 0
    }

    func loadAccountData() async {
        guard let token = accessToken, let userID = user?.id else { return }
        do {
            profile = try await LastCallAPI.shared.fetchProfile(userID: userID, accessToken: token)
            reactedStoryIDs = try await LastCallAPI.shared.fetchReactionStoryIDs(userID: userID, accessToken: token)
            let notifications = try await LastCallAPI.shared.fetchNotifications(userID: userID, accessToken: token)
            unreadNotifications = notifications.filter { $0.readAt == nil }.count
        } catch {
            // A valid auth session can exist while optional account data is unavailable.
        }
    }

    func submitStory(title: String, body: String, category: String, city: String, country: String, anonymous: Bool) async -> Bool {
        guard let token = accessToken, let userID = user?.id else {
            authMode = .signIn
            authPresented = true
            return false
        }
        do {
            try await LastCallAPI.shared.insertStory(title: title, body: body, category: category, city: city, country: country, anonymous: anonymous, accessToken: token, userID: userID)
            return true
        } catch {
            errorMessage = cleanError(error)
            return false
        }
    }

    func toggleReaction(for story: Story) async {
        guard let token = accessToken, let userID = user?.id else {
            authMode = .signIn
            authPresented = true
            return
        }
        let alreadyReacted = reactedStoryIDs.contains(story.id)
        do {
            let newState = try await LastCallAPI.shared.toggleBeerReaction(storyID: story.id, userID: userID, accessToken: token, reacted: alreadyReacted)
            if newState { reactedStoryIDs.insert(story.id) } else { reactedStoryIDs.remove(story.id) }
        } catch { errorMessage = cleanError(error) }
    }

    private func cleanError(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.contains("Invalid login credentials") { return "That email or password was not recognised." }
        if raw.contains("Email not confirmed") { return "Please confirm your email before signing in." }
        return raw.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
    }
}

enum AuthMode { case signIn, signUp }

enum AppTab: String, CaseIterable {
    case home = "Home", discover = "Discover", write = "Write", messages = "Messages", profile = "Profile"
    var icon: String {
        switch self { case .home: return "house.fill"; case .discover: return "magnifyingglass"; case .write: return "pencil.and.outline"; case .messages: return "bubble.left.and.bubble.right.fill"; case .profile: return "person.fill" }
    }
}

struct Story: Identifiable, Hashable {
    let id: UUID
    let title: String
    let body: String
    let author: String
    let location: String
    let category: String
    let reactions: Int
    let comments: Int
    let imageURL: URL?
    let isSample: Bool

    init(id: UUID = UUID(), title: String, body: String, author: String, location: String, category: String, reactions: Int, comments: Int, imageURL: URL?, isSample: Bool = false) {
        self.id = id; self.title = title; self.body = body; self.author = author; self.location = location; self.category = category; self.reactions = reactions; self.comments = comments; self.imageURL = imageURL; self.isSample = isSample
    }

    init(remote: RemoteStory) {
        self.init(id: remote.id, title: remote.title, body: remote.body, author: remote.anonymousName ?? "LAST CALL member", location: remote.location.isEmpty ? "Worldwide" : remote.location, category: remote.category, reactions: 0, comments: 0, imageURL: URL(string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1200&q=82"))
    }

    static let samples: [Story] = [
        Story(title: "Last night was one for the books", body: "Good friends, great drinks, and a story I’ll be telling for a long time. 🍻", author: "SAMPLE", location: "Dublin, Ireland", category: "After Hours", reactions: 124, comments: 12, imageURL: URL(string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1200&q=82"), isSample: true),
        Story(title: "Small pub, big conversations", body: "That’s the magic. Sometimes the quiet nights stay with you longest.", author: "SAMPLE", location: "Galway, Ireland", category: "Bar Wisdom", reactions: 89, comments: 7, imageURL: URL(string: "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?auto=format&fit=crop&w=1200&q=82"), isSample: true),
        Story(title: "Nothing beats a full cold one", body: "A few close ones, good people, and a proper last call.", author: "SAMPLE", location: "Cork, Ireland", category: "Closing Time", reactions: 156, comments: 14, imageURL: URL(string: "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?auto=format&fit=crop&w=1200&q=82"), isSample: true)
    ]
}

struct RootView: View {
    @EnvironmentObject private var model: LastCallModel
    var body: some View {
        TabView(selection: $model.selectedTab) {
            HomeView().tag(AppTab.home)
            DiscoverView().tag(AppTab.discover)
            WriteStoryView().tag(AppTab.write)
            MessagesView().tag(AppTab.messages)
            ProfileView().tag(AppTab.profile)
        }
        .tint(LCTheme.gold)
        .background(LCTheme.black.ignoresSafeArea())
        .sheet(isPresented: $model.authPresented) { AuthView(mode: $model.authMode) }
        .alert("LAST CALL", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "") }
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: LastCallModel
    @State private var selectedStory: Story?
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    AppHeader()
                    HeroView()
                    if let story = model.stories.first { StoryOfNightView(story: story) { selectedStory = story } }
                    SectionHeading(title: "Top Stories", action: "See all")
                    ForEach(model.stories) { story in StoryRow(story: story) { selectedStory = story } }
                    CategoryStrip()
                }
                .padding(.horizontal, 14).padding(.bottom, 28)
            }
            .background(LCTheme.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable { await model.loadStories() }
            .sheet(item: $selectedStory) { story in StoryDetailView(story: story) }
        }
    }
}

struct AppHeader: View {
    @EnvironmentObject private var model: LastCallModel
    var body: some View {
        HStack(spacing: 10) {
            Text("LAST CALL").font(.system(size: 15, weight: .bold, design: .serif)).tracking(2.6)
            Spacer()
            Button { model.selectedTab = .discover } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("Search stories")
            if model.hasSession {
                Button { model.selectedTab = .profile } label: { Circle().fill(LCTheme.green).frame(width: 27, height: 27).overlay(Text("LC").font(.system(size: 8, weight: .bold))) }.accessibilityLabel("Profile")
            } else {
                Button("SIGN IN") { model.authMode = .signIn; model.authPresented = true }.font(.system(size: 7, weight: .bold)).foregroundStyle(LCTheme.gold)
            }
        }
        .foregroundStyle(LCTheme.cream).padding(.top, 8)
    }
}

struct HeroView: View {
    @EnvironmentObject private var model: LastCallModel
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: URL(string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1400&q=85"))
                .overlay(LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.88)], startPoint: .top, endPoint: .bottom))
            VStack(alignment: .leading, spacing: 8) {
                Text("IRISH ROOTS · WORLDWIDE STORIES").font(.system(size: 8, weight: .semibold)).tracking(1.5).foregroundStyle(LCTheme.gold)
                Text("LAST CALL").font(.system(size: 44, weight: .bold, design: .serif)).tracking(-2)
                Text("Stories From Behind the Bar").font(.system(size: 21, weight: .bold, design: .serif).italic()).foregroundStyle(LCTheme.gold)
                Text("Funny. Strange. Heartwarming. Unforgettable.").font(.system(size: 11, design: .serif)).foregroundStyle(LCTheme.cream.opacity(0.85))
                Button("WRITE A STORY →") { model.selectedTab = .write }.buttonStyle(LCPrimaryButton()).padding(.top, 4)
            }.padding(18)
        }
        .frame(height: 310).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(LCTheme.gold.opacity(0.28), lineWidth: 1))
    }
}

struct StoryOfNightView: View {
    @EnvironmentObject private var model: LastCallModel
    let story: Story; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                RemoteImage(url: story.imageURL).frame(width: 126)
                VStack(alignment: .leading, spacing: 7) {
                    Text(story.isSample ? "SAMPLE · STORY OF THE NIGHT" : "STORY OF THE NIGHT · LAST CALL").font(.system(size: 7, weight: .bold)).tracking(1).foregroundStyle(LCTheme.gold)
                    Text(story.title).font(.system(size: 17, weight: .bold, design: .serif)).multilineTextAlignment(.leading)
                    Text(story.body).font(.system(size: 9, design: .serif)).foregroundStyle(LCTheme.muted).lineLimit(4)
                    Text("🍺 \(story.reactions)   ·   💬 \(story.comments)   ·   READ FULL STORY →").font(.system(size: 7, weight: .semibold)).foregroundStyle(LCTheme.gold)
                }.padding(12); Spacer(minLength: 0)
            }.frame(height: 166).background(LCTheme.card).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(LCTheme.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

struct StoryRow: View {
    let story: Story; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RemoteImage(url: story.imageURL).frame(width: 78, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(story.isSample ? "SAMPLE · \(story.category.uppercased())" : story.category.uppercased()).font(.system(size: 6, weight: .bold)).tracking(1).foregroundStyle(LCTheme.gold)
                    Text(story.title).font(.system(size: 13, weight: .bold, design: .serif)).multilineTextAlignment(.leading).lineLimit(2)
                    Text("\(story.author) · \(story.location)").font(.system(size: 7)).foregroundStyle(LCTheme.muted)
                    Text("🍺 \(story.reactions)   💬 \(story.comments)").font(.system(size: 7, weight: .semibold)).foregroundStyle(LCTheme.muted)
                }; Spacer(minLength: 0)
            }.padding(8).background(LCTheme.card).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(LCTheme.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

struct SectionHeading: View { let title: String; let action: String; var body: some View { HStack(alignment: .lastTextBaseline) { Text(title).font(.system(size: 20, weight: .bold, design: .serif)); Spacer(); Text(action.uppercased()).font(.system(size: 7, weight: .semibold)).tracking(1).foregroundStyle(LCTheme.gold) }.foregroundStyle(LCTheme.cream) } }

struct CategoryStrip: View {
    let categories = ["Closing Time", "After Hours", "Bar Wisdom", "Staff Hours"]
    let icons = ["moon.stars.fill", "clock.fill", "lightbulb.fill", "person.2.fill"]
    var body: some View { VStack(alignment: .leading, spacing: 9) { Text("EXPLORE BY CATEGORY").font(.system(size: 8, weight: .bold)).tracking(1.3).foregroundStyle(LCTheme.gold); HStack(spacing: 5) { ForEach(Array(categories.enumerated()), id: \.offset) { index, category in VStack(spacing: 5) { Image(systemName: icons[index]).font(.system(size: 15)).foregroundStyle(LCTheme.gold); Text(category).font(.system(size: 7, weight: .semibold, design: .serif)).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).frame(height: 78).background(LCTheme.card).overlay(Rectangle().stroke(LCTheme.line, lineWidth: 1)) } } } }

struct StoryDetailView: View {
    @EnvironmentObject private var model: LastCallModel
    @Environment(\.dismiss) private var dismiss
    let story: Story
    var reacted: Bool { model.reactedStoryIDs.contains(story.id) }
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    RemoteImage(url: story.imageURL).frame(height: 270)
                    Text(story.isSample ? "SAMPLE · \(story.category.uppercased())" : story.category.uppercased()).font(.system(size: 8, weight: .bold)).tracking(1.3).foregroundStyle(LCTheme.gold)
                    Text(story.title).font(.system(size: 30, weight: .bold, design: .serif))
                    Text("\(story.author) · \(story.location)").font(.system(size: 9)).foregroundStyle(LCTheme.muted)
                    Text(story.body).font(.system(size: 16, design: .serif)).lineSpacing(5)
                    if story.isSample { Text("Sample content — real LAST CALL stories will appear here once published.").font(.system(size: 9)).foregroundStyle(LCTheme.muted) }
                    HStack(spacing: 10) {
                        if !story.isSample { Button(reacted ? "🍺 Liked" : "🍺 React") { Task { await model.toggleReaction(for: story) } }.buttonStyle(LCOutlineButton()) }
                        Text("💬 \(story.comments)").font(.system(size: 9, weight: .semibold)).foregroundStyle(LCTheme.muted); Spacer()
                    }
                }.padding(14)
            }.background(LCTheme.black.ignoresSafeArea()).foregroundStyle(LCTheme.cream).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
        }
    }
}

struct DiscoverView: View {
    @EnvironmentObject private var model: LastCallModel
    @State private var query = ""
    @State private var selectedStory: Story?
    var filtered: [Story] { query.isEmpty ? model.stories : model.stories.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query) || $0.location.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) } }
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 14) { Text("Discover").font(.system(size: 31, weight: .bold, design: .serif)); TextField("Search stories, cities or categories", text: $query).textFieldStyle(LCTextFieldStyle()); ForEach(filtered) { story in StoryRow(story: story) { selectedStory = story } } }.padding(14) }.background(LCTheme.black.ignoresSafeArea()).foregroundStyle(LCTheme.cream).navigationBarHidden(true).sheet(item: $selectedStory) { StoryDetailView(story: $0) } } }
}

struct WriteStoryView: View {
    @EnvironmentObject private var model: LastCallModel
    @State private var title = ""; @State private var bodyText = ""; @State private var category = "Closing Time"; @State private var city = ""; @State private var country = ""; @State private var anonymous = true; @State private var submitting = false; @State private var submitted = false
    let categories = ["Closing Time", "After Hours", "Bar Wisdom", "Staff Hours"]
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 14) { Text("Write a story").font(.system(size: 31, weight: .bold, design: .serif)); Text("Funny, strange, heartwarming, unforgettable — whatever stayed with you.").font(.system(size: 13, design: .serif)).foregroundStyle(LCTheme.muted); TextField("Story title", text: $title).textFieldStyle(LCTextFieldStyle()); TextEditor(text: $bodyText).frame(minHeight: 230).scrollContentBackground(.hidden).padding(8).background(LCTheme.card).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(LCTheme.line)); Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0) } }.pickerStyle(.menu); HStack { TextField("City (optional)", text: $city).textFieldStyle(LCTextFieldStyle()); TextField("Country (optional)", text: $country).textFieldStyle(LCTextFieldStyle()) }; Toggle("Post anonymously", isOn: $anonymous).tint(LCTheme.green); Button(submitting ? "SUBMITTING…" : "SUBMIT STORY →") { submitting = true; Task { let ok = await model.submitStory(title: title, body: bodyText, category: category, city: city, country: country, anonymous: anonymous); submitting = false; if ok { submitted = true; title = ""; bodyText = ""; city = ""; country = "" } } }.buttonStyle(LCPrimaryButton()).disabled(submitting || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty); if submitted { Text("Thanks — your story has been sent for review.").font(.system(size: 10, weight: .semibold)).foregroundStyle(LCTheme.gold) }; Text(model.hasSession ? "Stories are reviewed before public publication." : "You’ll need a free LAST CALL account to submit a story.").font(.system(size: 9)).foregroundStyle(LCTheme.muted) }.padding(14) }.background(LCTheme.black.ignoresSafeArea()).foregroundStyle(LCTheme.cream).navigationBarHidden(true) } }
}

struct AuthView: View {
    @EnvironmentObject private var model: LastCallModel
    @Binding var mode: AuthMode
    @State private var email = ""; @State private var password = ""; @State private var displayName = ""; @State private var working = false; @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 14) { Text(mode == .signIn ? "Sign in" : "Become a free member").font(.system(size: 31, weight: .bold, design: .serif)); Text(mode == .signIn ? "Welcome back to LAST CALL." : "It’s completely FREE to join. No subscription. No fees. Just good stories.").font(.system(size: 13, design: .serif)).foregroundStyle(LCTheme.muted); if mode == .signUp { TextField("Name or display name (optional)", text: $displayName).textFieldStyle(LCTextFieldStyle()) }; TextField("Email", text: $email).textFieldStyle(LCTextFieldStyle()).textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled(); SecureField("Password", text: $password).textFieldStyle(LCTextFieldStyle()); Button(working ? "PLEASE WAIT…" : (mode == .signIn ? "SIGN IN →" : "CREATE FREE ACCOUNT →")) { working = true; Task { if mode == .signIn { await model.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) } else { await model.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, displayName: displayName.nilIfEmpty) }; working = false } }.buttonStyle(LCPrimaryButton()).disabled(working || email.isEmpty || password.count < 6); Button(mode == .signIn ? "Need an account? Become a free member" : "Already a member? Sign in") { mode = mode == .signIn ? .signUp : .signIn }.font(.system(size: 9, weight: .semibold)).foregroundStyle(LCTheme.gold); Text("Names can remain anonymous publicly if you choose.").font(.system(size: 9)).foregroundStyle(LCTheme.muted) }.padding(14) }.background(LCTheme.black.ignoresSafeArea()).foregroundStyle(LCTheme.cream).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } } } }
}

struct CommunityView: View {
    @EnvironmentObject private var model: LastCallModel
    @State private var profiles: [ProfileRow] = []; @State private var following = Set<UUID>(); @State private var loading = false; @State private var message: String?
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 12) { Text("Community").font(.system(size: 31, weight: .bold, design: .serif)); Text("Find people, follow storytellers, keep the craic going.").font(.system(size: 13, design: .serif)).foregroundStyle(LCTheme.muted); if let message { Text(message).font(.system(size: 10)).foregroundStyle(LCTheme.gold) }; ForEach(profiles) { person in HStack { Circle().fill(LCTheme.green).frame(width: 38).overlay(Text("LC").font(.system(size: 9, weight: .bold))); VStack(alignment: .leading) { Text(person.publicName).font(.system(size: 12, weight: .semibold)); Text(person.bio ?? "Storyteller").font(.system(size: 8)).foregroundStyle(LCTheme.muted).lineLimit(1) }; Spacer(); Button(following.contains(person.id) ? "Following" : "Follow") { Task { await toggle(person) } }.buttonStyle(LCOutlineButton()) } } }.padding(14) }.background(LCTheme.black.ignoresSafeArea()).foregroundStyle(LCTheme.cream).navigationTitle("Community").navigationBarTitleDisplayMode(.inline).task { await load() } } }
    private func load() async { guard let token = model.accessToken, let id = model.user?.id else { return }; loading = true; defer { loading = false }; do { profiles = try await LastCallAPI.shared.fetchProfiles(excluding: id, accessToken: token); following = try await LastCallAPI.shared.fetchFollowing(userID: id, accessToken: token) } catch { message = "Community could not be refreshed." } }
    private func toggle(_ person: ProfileRow) async { guard let token = model.accessToken, let id = model.user?.id else { return }; do { let next = try await LastCallAPI.shared.toggleFollow(targetID: person.id, userID: id, accessToken: token, following: following.contains(person.id)); if next { following.insert(person.id) } else { following.remove(person.id) } } catch { message = "That follow could not be changed." } }
}

struct MessagesView: View {
    @EnvironmentObject private var model: LastCallModel
    @State private var conversations: [ConversationRow] = []; @State private var selected: ConversationRow?; @State private var loading = false; @State private var showCommunity = false
    var body: some View { NavigationStack { Group { if !model.hasSession { VStack(spacing: 12) { Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 32)).foregroundStyle(LCTheme.gold); Text("Messages").font(.system(size: 25, weight: .bold, design: .serif)); Text("Sign in to message other LAST CALL members.").font(.system(size: 11)).foregroundStyle(LCTheme.muted); Button("SIGN IN →") { model.authMode = .signIn; model.authPresented = true }.buttonStyle(LCPrimaryButton()) } .padding(20) } else { List(conversations) { conversation in Button { selected = conversation } label: { HStack { Circle().fill(LCTheme.green).frame(width: 38).overlay(Text("LC").font(.system(size: 9, weight: .bold))); VStack(alignment: .leading) { Text(conversation.otherUser.publicName).font(.system(size: 12, weight: .semibold)); Text(conversation.latestMessage?.body ?? (conversation.status == "pending" ? "Message request" : "Start the conversation")).font(.system(size: 9)).foregroundStyle(LCTheme.muted).lineLimit(1) }; Spacer(); if conversation.status == "pending" { Text("REQUEST").font(.system(size: 6, weight: .bold)).foregroundStyle(LCTheme.gold) } } }.buttonStyle(.plain) }.scrollContentBackground(.hidden) } }.background(LCTheme.black).foregroundStyle(LCTheme.cream).navigationTitle("Messages").toolbar { if model.hasSession { ToolbarItem(placement: .topBarTrailing) { Button("Community") { showCommunity = true }.font(.system(size: 8, weight: .bold)) } } }.task { await load() }.sheet(item: $selected) { ChatView(conversation: $0) }.sheet(isPresented: $showCommunity) { CommunityView() } } }
    private func load() async { guard let token = model.accessToken, let id = model.user?.id else { return }; loading = true; defer { loading = false }; do { conversations = try await LastCallAPI.shared.fetchConversations(userID: id, accessToken: token) } catch {} }
}

struct ChatView: View {
    @EnvironmentObject private var model: LastCallModel
    let conversation: ConversationRow
    @State private var messages: [MessageRow] = []; @State private var text = ""; @State private var loading = false; @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { VStack(spacing: 0) { ScrollViewReader { proxy in ScrollView { LazyVStack(alignment: .leading, spacing: 8) { ForEach(messages) { message in HStack { if message.senderId == model.user?.id { Spacer(); Text(message.body).padding(10).background(LCTheme.green).clipShape(RoundedRectangle(cornerRadius: 12)).frame(maxWidth: 280, alignment: .trailing) } else { Text(message.body).padding(10).background(LCTheme.card).clipShape(RoundedRectangle(cornerRadius: 12)).frame(maxWidth: 280, alignment: .leading); Spacer() } }.id(message.id) } }.padding(12) }.onChange(of: messages.count) { _, _ in if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) } } }; HStack(spacing: 8) { TextField("Message", text: $text, axis: .vertical).textFieldStyle(LCTextFieldStyle()); Button("SEND") { Task { await send() } }.buttonStyle(LCPrimaryButton()).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.padding(10).background(LCTheme.card) }.background(LCTheme.black).foregroundStyle(LCTheme.cream).navigationTitle(conversation.otherUser.publicName).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }.task { await load() } } }
    private func load() async { guard let token = model.accessToken else { return }; do { messages = try await LastCallAPI.shared.fetchMessages(conversationID: conversation.id, accessToken: token) } catch {} }
    private func send() async { guard let token = model.accessToken, let id = model.user?.id else { return }; let body = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !body.isEmpty else { return }; text = ""; do { try await LastCallAPI.shared.sendMessage(conversationID: conversation.id, senderID: id, body: body, accessToken: token); messages = try await LastCallAPI.shared.fetchMessages(conversationID: conversation.id, accessToken: token) } catch { model.errorMessage = "That message could not be sent." } }
}

struct ProfileView: View {
    @EnvironmentObject private var model: LastCallModel
    @State private var showCommunity = false; @State private var showNotifications = false
    var body: some View { NavigationStack { ScrollView { VStack(spacing: 14) { RemoteImage(url: URL(string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1200&q=80")).frame(height: 180); Circle().fill(LCTheme.green).frame(width: 82).overlay(Text("LC").font(.system(size: 24, weight: .bold))); Text(model.profile?.publicName ?? (model.hasSession ? "LAST CALL MEMBER" : "Welcome to LAST CALL")).font(.system(size: 20, weight: .bold, design: .serif)); Text(model.profile?.bio ?? "Good stories. Great company. Always up for a last call. 🍻").font(.system(size: 12, design: .serif)).foregroundStyle(LCTheme.muted).multilineTextAlignment(.center); if model.hasSession { HStack { Stat(value: "🍺", label: "Your reactions"); Stat(value: model.unreadNotifications > 0 ? "\(model.unreadNotifications)" : "0", label: "Notifications"); Stat(value: "FREE", label: "Membership") }; Button("COMMUNITY") { showCommunity = true }.buttonStyle(LCOutlineButton()); Button("NOTIFICATIONS") { showNotifications = true }.buttonStyle(LCOutlineButton()); Button("SIGN OUT") { model.signOut() }.buttonStyle(LCOutlineButton()) } else { Button("BECOME A FREE MEMBER →") { model.authMode = .signUp; model.authPresented = true }.buttonStyle(LCPrimaryButton()); Button("SIGN IN") { model.authMode = .signIn; model.authPresented = true }.buttonStyle(LCOutlineButton()) } }.padding(14) }.background(LCTheme.black.ignoresSafeArea()).foregroundStyle(LCTheme.cream).navigationBarHidden(true).sheet(isPresented: $showCommunity) { CommunityView() }.sheet(isPresented: $showNotifications) { NotificationsView() } } }
}

struct NotificationsView: View {
    @EnvironmentObject private var model: LastCallModel
    @State private var notifications: [NotificationRow] = []
    var body: some View { NavigationStack { List(notifications) { note in VStack(alignment: .leading, spacing: 4) { Text(notificationText(note)).font(.system(size: 11, weight: note.readAt == nil ? .bold : .regular)); Text(note.createdAt.replacingOccurrences(of: "T", with: " ").prefix(16)).font(.system(size: 7)).foregroundStyle(LCTheme.muted) } }.scrollContentBackground(.hidden).background(LCTheme.black).foregroundStyle(LCTheme.cream).navigationTitle("Notifications").task { await load() } } }
    private func load() async { guard let token = model.accessToken, let id = model.user?.id else { return }; do { notifications = try await LastCallAPI.shared.fetchNotifications(userID: id, accessToken: token); if notifications.contains(where: { $0.readAt == nil }) { try? await LastCallAPI.shared.markNotificationsRead(userID: id, accessToken: token); model.unreadNotifications = 0 } } catch {} }
    private func notificationText(_ note: NotificationRow) -> String { switch note.type { case "message_request": return "You have a new message request."; case "message": return "You have a new message."; case "follow": return "Someone followed you."; default: return "You have a new LAST CALL notification." } }
}

struct Stat: View { let value: String; let label: String; var body: some View { VStack { Text(value).font(.system(size: 18, weight: .bold)); Text(label).font(.system(size: 7)).foregroundStyle(LCTheme.muted) }.frame(maxWidth: .infinity) } }
struct RemoteImage: View { let url: URL?; var body: some View { AsyncImage(url: url) { phase in switch phase { case .success(let image): image.resizable().scaledToFill(); default: Rectangle().fill(LCTheme.card).overlay(Image(systemName: "wineglass.fill").foregroundStyle(LCTheme.gold.opacity(0.5))) } }.clipped() } }
struct LCTheme { static let black = Color(red: 0.027, green: 0.027, blue: 0.024); static let card = Color(red: 0.055, green: 0.055, blue: 0.047); static let cream = Color(red: 0.957, green: 0.929, blue: 0.875); static let gold = Color(red: 0.843, green: 0.714, blue: 0.365); static let green = Color(red: 0.125, green: 0.357, blue: 0.216); static let muted = Color(red: 0.62, green: 0.59, blue: 0.53); static let line = Color(red: 0.843, green: 0.714, blue: 0.365).opacity(0.25) }
struct LCPrimaryButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 8, weight: .bold)).tracking(1.1).foregroundStyle(LCTheme.cream).padding(.horizontal, 14).frame(minHeight: 38).background(LCTheme.green).clipShape(RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(LCTheme.gold, lineWidth: 1)).opacity(configuration.isPressed ? 0.72 : 1) } }
struct LCOutlineButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 8, weight: .semibold)).tracking(0.8).foregroundStyle(LCTheme.cream).padding(.horizontal, 11).frame(minHeight: 32).background(LCTheme.card).clipShape(RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(LCTheme.line, lineWidth: 1)).opacity(configuration.isPressed ? 0.7 : 1) } }
struct LCTextFieldStyle: TextFieldStyle { func _body(configuration: TextField<Self._Label>) -> some View { configuration.font(.system(size: 12, design: .serif)).foregroundStyle(LCTheme.cream).padding(12).background(LCTheme.card).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(LCTheme.line)) } }
