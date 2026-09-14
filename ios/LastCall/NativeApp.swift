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
            if remote.isEmpty {
                stories = []
            } else {
                let ids = remote.map(\.id)
                let counts = (try? await LastCallAPI.shared.fetchReactionCounts(storyIDs: ids, accessToken: token ?? "")) ?? [:]
                stories = remote.map { NativeStory(remote: $0, reactions: counts[$0.id] ?? 0) }
            }
        } catch {
            self.error = "Stories could not be refreshed just now."
        }
        refreshID = UUID()
    }

    func refreshAccount() async {
        guard let t = token, let id = user?.id else { return }
        do {
            profile = try await LastCallAPI.shared.fetchProfile(userID: id, accessToken: t)
            reactions = try await LastCallAPI.shared.fetchReactionStoryIDs(userID: id, accessToken: t)
            unread = try await LastCallAPI.shared.fetchNotifications(userID: id, accessToken: t).filter { $0.readAt == nil }.count
        } catch { }
    }

    func signIn(_ email: String, _ password: String) async {
        do {
            let auth = try await LastCallAPI.shared.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            guard let t = auth.accessToken, let u = auth.user else { throw LastCallAPIError.server("Sign in did not return a session.") }
            token = t; user = u; signedIn = true; showAuth = false
            await refreshAccount()
        } catch let caughtError { self.error = authError(caughtError) }
    }

    func signUp(_ email: String, _ password: String, _ name: String) async {
        do {
            let auth = try await LastCallAPI.shared.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, displayName: name.nilIfEmpty)
            if let t = auth.accessToken, let u = auth.user {
                token = t; user = u; signedIn = true; showAuth = false; await refreshAccount()
            } else {
                error = "Account created. Check your email to confirm your address, then come back to LAST CALL and sign in."
            }
        } catch let caughtError { self.error = authError(caughtError) }
    }

    func signOut() { LastCallAPI.shared.signOut(); token = nil; user = nil; profile = nil; signedIn = false; reactions = []; unread = 0 }

    func react(_ story: NativeStory) async {
        guard let t = token, let id = user?.id else { authMode = .signIn; showAuth = true; return }
        do {
            let active = reactions.contains(story.id)
            _ = try await LastCallAPI.shared.toggleBeerReaction(storyID: story.id, userID: id, accessToken: t, reacted: active)
            if active { reactions.remove(story.id) } else { reactions.insert(story.id) }
            await refreshStories()
        } catch { self.error = "That reaction could not be saved." }
    }

    func submit(title: String, body: String, category: String, city: String, country: String, anonymous: Bool) async -> Bool {
        guard let t = token, let id = user?.id else { authMode = .signIn; showAuth = true; return false }
        do { try await LastCallAPI.shared.insertStory(title: title, body: body, category: category, city: city, country: country, anonymous: anonymous, accessToken: t, userID: id); return true }
        catch { self.error = "Your story could not be sent just now."; return false }
    }

    private func authError(_ e: Error) -> String {
        let s = e.localizedDescription
        if s.contains("Invalid login credentials") { return "That email or password was not recognised." }
        if s.contains("Email not confirmed") { return "Please confirm your email before signing in." }
        if s.lowercased().contains("already registered") { return "That email already has a LAST CALL account. Try signing in." }
        return s
    }
}

enum NativeTab: String, CaseIterable { case home = "Home", discover = "Explore", write = "Write", messages = "Messages", profile = "Profile" }

struct NativeRootView: View {
    @EnvironmentObject private var model: NativeAppModel
    var body: some View {
        Group {
            if model.session {
                TabView(selection: $model.tab) {
                    CommunityHome()
                        .tag(NativeTab.home)
                        .tabItem { Label("Home", systemImage: "house.fill") }
                    NativeDiscover()
                        .tag(NativeTab.discover)
                        .tabItem { Label("Explore", systemImage: "safari") }
                    NativeWrite()
                        .tag(NativeTab.write)
                        .tabItem { Label("Write", systemImage: "plus.circle.fill") }
                    NativeMessages()
                        .tag(NativeTab.messages)
                        .tabItem { Label("Messages", systemImage: "message.fill") }
                    NativeProfile()
                        .tag(NativeTab.profile)
                        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                }
                .tint(Look.gold)
            } else {
                LockedHome()
            }
        }
        .background(Look.black.ignoresSafeArea())
        .sheet(isPresented: $model.showAuth) { NativeAuth(mode: $model.authMode) }
        .alert("LAST CALL", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK", role: .cancel) {} } message: { Text(model.error ?? "") }
    }
}

struct NativeHeader: View {
    @EnvironmentObject private var model: NativeAppModel
    var body: some View {
        HStack {
            Text("LAST CALL").font(.system(size: 15, weight: .bold, design: .serif)).tracking(2.4)
            Spacer()
            Button { model.tab = .discover } label: { Image(systemName: "magnifyingglass") }
            if model.session { Button { model.tab = .profile } label: { Circle().fill(Look.green).frame(width: 27, height: 27).overlay(Text("LC").font(.system(size: 8, weight: .bold))) } } else { Button("SIGN IN") { model.authMode = .signIn; model.showAuth = true }.font(.system(size: 7, weight: .bold)) }
        }.foregroundStyle(Look.cream).padding(.top, 6)
    }
}

struct NativeHome: View {
    @EnvironmentObject private var model: NativeAppModel
    @State private var selected: NativeStory?
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    NativeHeader()
                    NativeHero()
                    if let story = model.stories.first { NativeFeature(story: story) { selected = story } }
                    HStack { Text("TOP STORIES").font(.system(size: 18, weight: .bold, design: .serif)); Spacer(); Text("SEE ALL").font(.system(size: 7, weight: .bold)).foregroundStyle(Look.gold) }.foregroundStyle(Look.cream)
                    if model.stories.isEmpty {
                        Text("No published stories yet. If you’ve got a story, we’d love to hear it.").font(.system(size: 11, design: .serif)).foregroundStyle(Look.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                    } else {
                        ForEach(model.stories.prefix(5)) { story in NativeStoryRow(story: story) { selected = story } }
                    }
                    NativeCategories()
                }.padding(.horizontal, 13).padding(.bottom, 24)
            }.background(Look.black.ignoresSafeArea()).navigationBarHidden(true).refreshable { await model.refreshStories() }.sheet(item: $selected) { NativeStoryDetail(story: $0) }
        }
    }
}

struct NativeHero: View {
    @EnvironmentObject private var model: NativeAppModel
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            NativeImage(url: URL(string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1400&q=85"))
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom))
            VStack(alignment: .leading, spacing: 7) {
                Text("IRISH ROOTS · WORLDWIDE STORIES").font(.system(size: 7, weight: .bold)).tracking(1.4).foregroundStyle(Look.gold)
                Text("LAST CALL").font(.system(size: 43, weight: .bold, design: .serif)).tracking(-2)
                Text("Stories From Behind the Bar").font(.system(size: 20, weight: .bold, design: .serif).italic()).foregroundStyle(Look.gold)
                Text("Funny. Strange. Heartwarming. Unforgettable.").font(.system(size: 10, design: .serif)).foregroundStyle(Look.cream.opacity(0.86))
                Button("WRITE A STORY →") { model.tab = .write }.buttonStyle(PrimaryButton()).padding(.top, 2)
            }.padding(17)
        }.frame(height: 285).clipShape(RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Look.gold.opacity(0.25)))
    }
}

struct NativeFeature: View {
    let story: NativeStory; let action: () -> Void
    var body: some View { Button(action: action) { HStack(spacing: 0) { NativeImage(url: story.imageURL).frame(width: 118); VStack(alignment: .leading, spacing: 6) { Text(story.isSample ? "SAMPLE · STORY OF THE NIGHT" : "STORY OF THE NIGHT · LAST CALL").font(.system(size: 6, weight: .bold)).tracking(1).foregroundStyle(Look.gold); Text(story.title).font(.system(size: 16, weight: .bold, design: .serif)).multilineTextAlignment(.leading); Text(story.body).font(.system(size: 9, design: .serif)).foregroundStyle(Look.muted).lineLimit(4); Text("🍺 \(story.reactions)   ·   💬 \(story.comments)   ·   READ FULL STORY →").font(.system(size: 6, weight: .bold)).foregroundStyle(Look.gold) }.padding(11); Spacer() }.frame(height: 158).background(Look.card).clipShape(RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(Look.line)) }.buttonStyle(.plain) }
}

struct NativeStoryRow: View { let story: NativeStory; let action: () -> Void; var body: some View { Button(action: action) { HStack(spacing: 9) { NativeImage(url: story.imageURL).frame(width: 74, height: 68); VStack(alignment: .leading, spacing: 3) { Text(story.isSample ? "SAMPLE · \(story.category.uppercased())" : story.category.uppercased()).font(.system(size: 6, weight: .bold)).foregroundStyle(Look.gold); Text(story.title).font(.system(size: 12, weight: .bold, design: .serif)).lineLimit(2); Text("\(story.author) · \(story.location)").font(.system(size: 7)).foregroundStyle(Look.muted); Text("🍺 \(story.reactions)   💬 \(story.comments)").font(.system(size: 6, weight: .semibold)).foregroundStyle(Look.muted) }; Spacer() }.padding(8).background(Look.card).clipShape(RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).stroke(Look.line)) }.buttonStyle(.plain) } }

struct NativeCategories: View { let names = ["Closing Time", "After Hours", "Bar Wisdom", "Staff Hours"]; let icons = ["moon.stars.fill", "clock.fill", "lightbulb.fill", "person.2.fill"]; var body: some View { VStack(alignment: .leading, spacing: 8) { Text("EXPLORE BY CATEGORY").font(.system(size: 7, weight: .bold)).tracking(1.2).foregroundStyle(Look.gold); HStack(spacing: 5) { ForEach(0..<4) { i in VStack(spacing: 5) { Image(systemName: icons[i]).foregroundStyle(Look.gold); Text(names[i]).font(.system(size: 7, weight: .semibold, design: .serif)).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).frame(height: 70).background(Look.card).overlay(Rectangle().stroke(Look.line)) } } } } }

struct NativeDiscover: View {
    @EnvironmentObject private var model: NativeAppModel; @State private var query = ""; @State private var selected: NativeStory?
    var filtered: [NativeStory] { query.isEmpty ? model.stories : model.stories.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query) || $0.location.localizedCaseInsensitiveContains(query) } }
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 12) { Text("Stories").font(.system(size: 31, weight: .bold, design: .serif)); TextField("Search stories, cities or categories", text: $query).textFieldStyle(LCField()); if filtered.isEmpty { Text(query.isEmpty ? "No published stories yet." : "No stories matched that search.").font(.system(size: 11, design: .serif)).foregroundStyle(Look.muted).padding(.vertical, 18) } else { ForEach(filtered) { story in NativeStoryRow(story: story) { selected = story } } } }.padding(13) }.background(Look.black.ignoresSafeArea()).foregroundStyle(Look.cream).navigationBarHidden(true).sheet(item: $selected) { NativeStoryDetail(story: $0) } } }
}

struct NativeStoryDetail: View {
    @EnvironmentObject private var model: NativeAppModel; let story: NativeStory; @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 12) { NativeImage(url: story.imageURL).frame(height: 245); Text(story.category.uppercased()).font(.system(size: 7, weight: .bold)).tracking(1.2).foregroundStyle(Look.gold); Text(story.title).font(.system(size: 29, weight: .bold, design: .serif)); Text("\(story.author) · \(story.location)").font(.system(size: 8)).foregroundStyle(Look.muted); Text(story.body).font(.system(size: 16, design: .serif)).lineSpacing(5); HStack { if !story.isSample { Button(model.reactions.contains(story.id) ? "🍺 LIKED" : "🍺 REACT") { Task { await model.react(story) } }.buttonStyle(OutlineButton()) }; Spacer(); Text("💬 \(story.comments)").font(.system(size: 8, weight: .semibold)).foregroundStyle(Look.muted) } }.padding(13) }.background(Look.black.ignoresSafeArea()).foregroundStyle(Look.cream).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } } } }
}

struct NativeWrite: View {
    @EnvironmentObject private var model: NativeAppModel; @State private var title = ""; @State private var bodyText = ""; @State private var category = "Closing Time"; @State private var city = ""; @State private var country = ""; @State private var anonymous = true; @State private var sending = false; @State private var done = false
    let categories = ["Closing Time", "After Hours", "Bar Wisdom", "Staff Hours"]
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 12) { Text("Tell us your story").font(.system(size: 31, weight: .bold, design: .serif)); Text("Funny, strange, heartwarming, unforgettable — whatever stayed with you.").font(.system(size: 12, design: .serif)).foregroundStyle(Look.muted); TextField("Story title", text: $title).textFieldStyle(LCField()); TextEditor(text: $bodyText).frame(minHeight: 230).scrollContentBackground(.hidden).padding(8).background(Look.card).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Look.line)); Picker("Category", selection: $category) { ForEach(categories, id: \.self, content: Text.init) }.pickerStyle(.menu); HStack { TextField("City", text: $city).textFieldStyle(LCField()); TextField("Country", text: $country).textFieldStyle(LCField()) }; Toggle("Post anonymously", isOn: $anonymous).tint(Look.green); Button(sending ? "SENDING…" : "SUBMIT STORY →") { sending = true; Task { let ok = await model.submit(title: title, body: bodyText, category: category, city: city, country: country, anonymous: anonymous); sending = false; if ok { done = true; title = ""; bodyText = ""; city = ""; country = "" } } }.buttonStyle(PrimaryButton()).disabled(sending || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty); if done { Text("Thanks — your story has been sent for review.").font(.system(size: 9, weight: .semibold)).foregroundStyle(Look.gold) }; Text(model.session ? "Stories are reviewed before public publication." : "You’ll need a free LAST CALL account to submit a story.").font(.system(size: 9)).foregroundStyle(Look.muted) }.padding(13) }.background(Look.black.ignoresSafeArea()).foregroundStyle(Look.cream).navigationBarHidden(true) } }
}

struct NativeAuth: View {
    @EnvironmentObject private var model: NativeAppModel; @Binding var mode: AuthMode; @State private var email = ""; @State private var password = ""; @State private var name = ""; @State private var working = false; @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 12) { Text(mode == .signIn ? "Welcome back" : "Become a free member").font(.system(size: 30, weight: .bold, design: .serif)); Text(mode == .signIn ? "Good stories. Great company. That’s the craic." : "It’s completely FREE to join. No subscription. No fees. Just good stories.").font(.system(size: 12, design: .serif)).foregroundStyle(Look.muted); if mode == .signUp { TextField("Name or display name (optional)", text: $name).textFieldStyle(LCField()) }; TextField("Email", text: $email).textFieldStyle(LCField()).textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled(); SecureField("Password", text: $password).textFieldStyle(LCField()); Button(working ? "PLEASE WAIT…" : (mode == .signIn ? "SIGN IN →" : "CREATE FREE ACCOUNT →")) { working = true; Task { if mode == .signIn { await model.signIn(email, password) } else { await model.signUp(email, password, name) }; working = false } }.buttonStyle(PrimaryButton()).disabled(working || email.isEmpty || password.count < 6); Button(mode == .signIn ? "Need an account? Become a free member" : "Already a member? Sign in") { mode = mode == .signIn ? .signUp : .signIn }.font(.system(size: 9, weight: .semibold)).foregroundStyle(Look.gold); Text("Names can remain anonymous publicly if you choose.").font(.system(size: 9)).foregroundStyle(Look.muted) }.padding(13) }.background(Look.black.ignoresSafeArea()).foregroundStyle(Look.cream).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } } } }
}

struct NativeCommunity: View {
    @EnvironmentObject private var model: NativeAppModel; @State private var people: [ProfileRow] = []; @State private var following = Set<UUID>(); @State private var selected: ProfileRow?; @State private var loading = false; @State private var message: String?
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 11) { Text("Community").font(.system(size: 30, weight: .bold, design: .serif)); Text("Find people, follow storytellers, keep the craic going.").font(.system(size: 12, design: .serif)).foregroundStyle(Look.muted); if let message { Text(message).font(.system(size: 9)).foregroundStyle(Look.gold) }; ForEach(people) { person in HStack(spacing: 8) { Circle().fill(Look.green).frame(width: 38).overlay(Text("LC").font(.system(size: 8, weight: .bold))); VStack(alignment: .leading) { Text(person.publicName).font(.system(size: 11, weight: .semibold)); Text(person.bio ?? "Storyteller").font(.system(size: 8)).foregroundStyle(Look.muted).lineLimit(1) }; Spacer(); if person.id != model.user?.id { Button(following.contains(person.id) ? "Following" : "Follow") { Task { await toggle(person) } }.buttonStyle(OutlineButton()); Button { selected = person } label: { Image(systemName: "message.fill") }.foregroundStyle(Look.gold).accessibilityLabel("Message \(person.publicName)") } }.padding(8).background(Look.card).clipShape(RoundedRectangle(cornerRadius: 10)) } }.padding(13) }.background(Look.black.ignoresSafeArea()).foregroundStyle(Look.cream).navigationBarHidden(true).task { await load() }.sheet(item: $selected) { person in NewConversationSheet(person: person) } } }
    private func load() async { guard let t = model.token, let id = model.user?.id else { message = "Sign in to follow storytellers and message people."; return }; loading = true; defer { loading = false }; do { people = try await LastCallAPI.shared.fetchProfiles(excluding: id, accessToken: t); following = try await LastCallAPI.shared.fetchFollowing(userID: id, accessToken: t) } catch { message = "Community could not be refreshed." } }
    private func toggle(_ p: ProfileRow) async { guard let t = model.token, let id = model.user?.id else { return }; do { let next = try await LastCallAPI.shared.toggleFollow(targetID: p.id, userID: id, accessToken: t, following: following.contains(p.id)); if next { following.insert(p.id) } else { following.remove(p.id) } } catch { message = "That follow could not be changed." } }
}

struct NewConversationSheet: View {
    @EnvironmentObject private var model: NativeAppModel; let person: ProfileRow; @State private var starting = false; @Environment(\.dismiss) private var dismiss
    var body: some View { VStack(spacing: 14) { Circle().fill(Look.green).frame(width: 58).overlay(Text("LC").font(.system(size: 12, weight: .bold))); Text(person.publicName).font(.system(size: 22, weight: .bold, design: .serif)); Text("Start a conversation with this LAST CALL member.").font(.system(size: 10, design: .serif)).foregroundStyle(Look.muted); Button(starting ? "STARTING…" : "MESSAGE →") { starting = true; Task { guard let t = model.token else { return }; do { let id = try await LastCallAPI.shared.startConversation(targetID: person.id, accessToken: t); starting = false; dismiss(); model.tab = .messages; ConversationRouter.shared.open(id) } catch { starting = false; model.error = "You can’t message this member with their current privacy settings." } } }.buttonStyle(PrimaryButton()); Button("Cancel") { dismiss() }.font(.system(size: 9)).foregroundStyle(Look.muted) }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(Look.black.ignoresSafeArea()).foregroundStyle(Look.cream) }
}

@MainActor final class ConversationRouter: ObservableObject { static let shared = ConversationRouter(); @Published var openID: UUID?; func open(_ id: UUID) { openID = id } }

struct NativeMessages: View {
    @EnvironmentObject private var model: NativeAppModel; @State private var conversations: [ConversationRow] = []; @State private var selected: ConversationRow?; @StateObject private var router = ConversationRouter.shared
    var body: some View { NavigationStack { Group { if !model.session { VStack(spacing: 12) { Text("Messages").font(.system(size: 27, weight: .bold, design: .serif)); Text("Sign in to message other LAST CALL members.").font(.system(size: 11)).foregroundStyle(Look.muted); Button("SIGN IN →") { model.authMode = .signIn; model.showAuth = true }.buttonStyle(PrimaryButton()) } } else { List(conversations) { c in Button { selected = c } label: { HStack { Circle().fill(Look.green).frame(width: 38).overlay(Text("LC").font(.system(size: 8, weight: .bold))); VStack(alignment: .leading) { Text(c.otherUser.publicName).font(.system(size: 11, weight: .semibold)); Text(c.latestMessage?.body ?? (c.status == "pending" ? "Message request" : "Start the conversation")).font(.system(size: 8)).foregroundStyle(Look.muted).lineLimit(1) }; Spacer(); if c.status == "pending" { Text("REQUEST").font(.system(size: 6, weight: .bold)).foregroundStyle(Look.gold) } } } } .scrollContentBackground(.hidden) } }.background(Look.black).foregroundStyle(Look.cream).navigationTitle("Messages").toolbar { if model.session { ToolbarItem(placement: .topBarTrailing) { Button("People") { showPeople = true }.font(.system(size: 8, weight: .bold)) } } }.task { await load() }.onChange(of: router.openID) { _, id in if let id { Task { await load(); selected = conversations.first(where: { $0.id == id }); router.openID = nil } } }.sheet(item: $selected) { NativeChat(conversation: $0) }.sheet(isPresented: $showPeople) { NativeCommunity() } } }
    @State private var showPeople = false
    private func load() async { guard let t = model.token, let id = model.user?.id else { return }; do { conversations = try await LastCallAPI.shared.fetchConversations(userID: id, accessToken: t) } catch {} }
}

struct NativeChat: View {
    @EnvironmentObject private var model: NativeAppModel; let conversation: ConversationRow; @State private var messages: [MessageRow] = []; @State private var text = ""; @State private var working = false; @Environment(\.dismiss) private var dismiss
    var pending: Bool { conversation.status == "pending" }
    var body: some View { NavigationStack { VStack(spacing: 0) { if pending { VStack(spacing: 8) { Text("MESSAGE REQUEST").font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(Look.gold); Text("Accept this request to start chatting, or block the member.").font(.system(size: 9)).foregroundStyle(Look.muted); HStack { Button("ACCEPT") { Task { await respond("accepted") } }.buttonStyle(PrimaryButton()); Button("BLOCK") { Task { await respond("blocked") } }.buttonStyle(OutlineButton()) } }.padding(11).background(Look.card) }; ScrollViewReader { proxy in ScrollView { LazyVStack(alignment: .leading, spacing: 8) { ForEach(messages) { m in HStack { if m.senderId == model.user?.id { Spacer(); Text(m.body).padding(10).background(Look.green).clipShape(RoundedRectangle(cornerRadius: 12)).frame(maxWidth: 280, alignment: .trailing) } else { Text(m.body).padding(10).background(Look.card).clipShape(RoundedRectangle(cornerRadius: 12)).frame(maxWidth: 280, alignment: .leading); Spacer() } }.id(m.id).task { if m.senderId != model.user?.id, let t = model.token { try? await LastCallAPI.shared.markMessageRead(messageID: m.id, accessToken: t) } } } }.padding(11) }.onChange(of: messages.count) { _, _ in if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) } } }; if !pending { HStack(spacing: 7) { TextField("Message", text: $text, axis: .vertical).textFieldStyle(LCField()); Button("SEND") { Task { await send() } }.buttonStyle(PrimaryButton()).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working) }.padding(9).background(Look.card) } }.background(Look.black).foregroundStyle(Look.cream).navigationTitle(conversation.otherUser.publicName).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }.task { await load() } } }
    private func load() async { guard let t = model.token else { return }; messages = (try? await LastCallAPI.shared.fetchMessages(conversationID: conversation.id, accessToken: t)) ?? [] }
    private func respond(_ decision: String) async { guard let t = model.token else { return }; do { try await LastCallAPI.shared.respondToMessageRequest(conversationID: conversation.id, decision: decision, accessToken: t); dismiss() } catch { model.error = "That request could not be updated." } }
    private func send() async { guard let t = model.token, let id = model.user?.id else { return }; let b = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !b.isEmpty else { return }; working = true; text = ""; do { try await LastCallAPI.shared.sendMessage(conversationID: conversation.id, senderID: id, body: b, accessToken: t); messages = (try? await LastCallAPI.shared.fetchMessages(conversationID: conversation.id, accessToken: t)) ?? messages } catch { model.error = "That message could not be sent." }; working = false }
}

struct NativeProfile: View {
    @EnvironmentObject private var model: NativeAppModel; @State private var notes: [NotificationRow] = []; @State private var showNotes = false; @State private var showPeople = false
    var body: some View { NavigationStack { ScrollView { VStack(spacing: 13) { NativeImage(url: URL(string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1200&q=80")).frame(height: 165); Circle().fill(Look.green).frame(width: 78).overlay(Text("LC").font(.system(size: 22, weight: .bold))); Text(model.profile?.publicName ?? (model.session ? "LAST CALL MEMBER" : "Welcome to LAST CALL")).font(.system(size: 20, weight: .bold, design: .serif)); Text(model.profile?.bio ?? "Good stories. Great company. Always up for a last call. 🍻").font(.system(size: 11, design: .serif)).foregroundStyle(Look.muted).multilineTextAlignment(.center); if model.session { HStack { Stat(value: "🍺", label: "Reactions"); Stat(value: "\(model.unread)", label: "Notifications"); Stat(value: "FREE", label: "Membership") }; Button("NOTIFICATIONS") { showNotes = true }.buttonStyle(OutlineButton()); Button("COMMUNITY") { showPeople = true }.buttonStyle(OutlineButton()); Button("SIGN OUT") { model.signOut() }.buttonStyle(OutlineButton()) } else { Button("BECOME A FREE MEMBER →") { model.authMode = .signUp; model.showAuth = true }.buttonStyle(PrimaryButton()); Button("SIGN IN") { model.authMode = .signIn; model.showAuth = true }.buttonStyle(OutlineButton()) } }.padding(13) }.background(Look.black.ignoresSafeArea()).foregroundStyle(Look.cream).navigationBarHidden(true).sheet(isPresented: $showNotes) { NativeNotifications(notes: notes) }.sheet(isPresented: $showPeople) { NativeCommunity() }.task { await loadNotes() } } }
    private func loadNotes() async { guard let t = model.token, let id = model.user?.id else { return }; notes = (try? await LastCallAPI.shared.fetchNotifications(userID: id, accessToken: t)) ?? [] }
}

struct NativeNotifications: View { @EnvironmentObject private var model: NativeAppModel; let notes: [NotificationRow]; @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { List(notes) { n in VStack(alignment: .leading, spacing: 4) { Text(label(n)).font(.system(size: 11, weight: .semibold)); Text(n.createdAt).font(.system(size: 7)).foregroundStyle(Look.muted) } }.scrollContentBackground(.hidden).background(Look.black).foregroundStyle(Look.cream).navigationTitle("Notifications").toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }.task { if let t = model.token, let id = model.user?.id { try? await LastCallAPI.shared.markNotificationsRead(userID: id, accessToken: t); model.unread = 0 } } } }
    private func label(_ n: NotificationRow) -> String { switch n.type { case "message_request": return "You have a new message request."; case "new_message": return "You have a new message."; case "new_follower": return "Someone followed you."; default: return "You have a new LAST CALL notification." } }
}

struct NativeStory: Identifiable, Hashable {
    let id: UUID; let title: String; let body: String; let author: String; let location: String; let category: String; let reactions: Int; let comments: Int; let imageURL: URL?; let isSample: Bool
    init(id: UUID = UUID(), title: String, body: String, author: String, location: String, category: String, reactions: Int, comments: Int, imageURL: URL?, isSample: Bool = false) { self.id=id; self.title=title; self.body=body; self.author=author; self.location=location; self.category=category; self.reactions=reactions; self.comments=comments; self.imageURL=imageURL; self.isSample=isSample }
    init(remote: RemoteStory, reactions: Int) { self.init(id: remote.id, title: remote.title, body: remote.body, author: remote.anonymousName ?? "LAST CALL member", location: remote.location.isEmpty ? "Worldwide" : remote.location, category: remote.category, reactions: reactions, comments: 0, imageURL: URL(string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1200&q=82")) }
    static let samples = [NativeStory(title: "The Customer Who Refused to Take the Hint", body: "Sample content — real LAST CALL stories will appear here once published.", author: "SAMPLE", location: "Dublin, Ireland", category: "Closing Time", reactions: 142, comments: 12, imageURL: URL(string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1200&q=82"), isSample: true), NativeStory(title: "We Definitely Shouldn’t Have Stayed for One More", body: "Sample content — real LAST CALL stories will appear here once published.", author: "SAMPLE", location: "Galway, Ireland", category: "After Hours", reactions: 112, comments: 9, imageURL: URL(string: "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?auto=format&fit=crop&w=1200&q=82"), isSample: true), NativeStory(title: "Never Trust a Man Who Says ‘Just One Quick Pint’", body: "Sample content — real LAST CALL stories will appear here once published.", author: "SAMPLE", location: "Cork, Ireland", category: "Bar Wisdom", reactions: 89, comments: 7, imageURL: URL(string: "https://images.unsplash.com/photo-1527761939622-933c0a2a6a57?auto=format&fit=crop&w=1200&q=82"), isSample: true)]
}

struct NativeImage: View { let url: URL?; var body: some View { AsyncImage(url: url) { phase in switch phase { case .success(let image): image.resizable().scaledToFill(); default: Rectangle().fill(Look.card) } }.clipped() } }
struct Stat: View { let value: String; let label: String; var body: some View { VStack(spacing: 3) { Text(value).font(.system(size: 15, weight: .bold)); Text(label.uppercased()).font(.system(size: 6, weight: .bold)).tracking(1).foregroundStyle(Look.muted) }.frame(maxWidth: .infinity) } }
struct PrimaryButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(Look.black).padding(.horizontal, 13).padding(.vertical, 9).background(Look.gold).clipShape(RoundedRectangle(cornerRadius: 7)).opacity(configuration.isPressed ? 0.75 : 1) } }
struct OutlineButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 7, weight: .bold)).tracking(0.8).foregroundStyle(Look.gold).padding(.horizontal, 9).padding(.vertical, 7).background(Look.card).clipShape(RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(Look.gold.opacity(0.35))).opacity(configuration.isPressed ? 0.7 : 1) } }
struct LCField: TextFieldStyle { func _body(configuration: TextField<Self._Label>) -> some View { configuration.padding(11).background(Look.card).foregroundStyle(Look.cream).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Look.line)) } }
struct Look { static let black = Color(red: 0.03, green: 0.03, blue: 0.025); static let card = Color(red: 0.08, green: 0.075, blue: 0.065); static let cream = Color(red: 0.95, green: 0.92, blue: 0.85); static let gold = Color(red: 0.84, green: 0.70, blue: 0.34); static let green = Color(red: 0.12, green: 0.36, blue: 0.22); static let muted = Color(red: 0.62, green: 0.59, blue: 0.52); static let line = Color.white.opacity(0.10) }
