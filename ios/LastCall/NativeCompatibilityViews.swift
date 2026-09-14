import SwiftUI

struct NativeStoryDetail: View {
    @EnvironmentObject private var model: NativeAppModel
    let story: NativeStory
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    NativeImage(url: story.imageURL).frame(height: 235).clipShape(RoundedRectangle(cornerRadius: 14))
                    Text(story.category.uppercased()).font(.system(size: 7, weight: .bold)).tracking(1.3).foregroundStyle(Look.gold)
                    Text(story.title).font(.system(size: 29, weight: .bold, design: .serif))
                    Text("\(story.author) · \(story.location)").font(.system(size: 9)).foregroundStyle(Look.muted)
                    Text(story.body).font(.system(size: 15, design: .serif)).lineSpacing(5)
                    HStack(spacing: 10) {
                        Button { Task { await model.react(story) } } label: {
                            Label("\(story.reactions + (model.reactions.contains(story.id) ? 1 : 0))", systemImage: model.reactions.contains(story.id) ? "beer.fill" : "mug.fill")
                        }.buttonStyle(PrimaryButton())
                        Text("Comments coming from the community").font(.system(size: 8)).foregroundStyle(Look.muted)
                    }
                }.padding(15)
            }.background(Look.black.ignoresSafeArea()).foregroundStyle(Look.cream)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() }.foregroundStyle(Look.gold) } }
        }
    }
}

struct NativeCommunity: View {
    @EnvironmentObject private var model: NativeAppModel
    @State private var people: [ProfileRow] = []
    @State private var loading = true
    var body: some View {
        NavigationStack {
            List {
                if loading { ProgressView().tint(Look.gold).listRowBackground(Look.black) }
                ForEach(people) { person in
                    HStack(spacing: 12) {
                        LastCallAvatar().frame(width: 44, height: 44).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.publicName).font(.system(size: 14, weight: .bold, design: .serif))
                            if let username = person.username, !username.isEmpty { Text("@\(username)").font(.system(size: 8)).foregroundStyle(Look.gold) }
                        }
                        Spacer()
                        Button { Task { try? await start(person) } } label: { Image(systemName: "message") }.foregroundStyle(Look.gold)
                    }.listRowBackground(Look.card)
                }
            }.scrollContentBackground(.hidden).background(Look.black).foregroundStyle(Look.cream)
            .navigationTitle("COMMUNITY").task { await load() }
        }
    }
    private func load() async { guard let token = model.token else { loading = false; return }; do { people = try await LastCallAPI.shared.fetchProfiles(excluding: model.user?.id, accessToken: token) } catch {}; loading = false }
    private func start(_ person: ProfileRow) async throws { guard let token = model.token else { return }; _ = try await LastCallAPI.shared.startConversation(targetID: person.id, accessToken: token); await MainActor.run { model.tab = .messages } }
}

struct NewConversationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let people: [ProfileRow]
    let action: (ProfileRow) -> Void
    var body: some View {
        NavigationStack {
            List(people) { person in
                Button { action(person); dismiss() } label: {
                    HStack(spacing: 10) { LastCallAvatar().frame(width: 40, height: 40).clipShape(Circle()); Text(person.publicName).foregroundStyle(Look.cream); Spacer(); Image(systemName: "message").foregroundStyle(Look.gold) }
                }.listRowBackground(Look.card)
            }.scrollContentBackground(.hidden).background(Look.black)
            .navigationTitle("NEW MESSAGE").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

struct ConversationRouter: View {
    let conversation: ConversationRow
    var body: some View { NativeChat(conversation: conversation) }
}

struct NativeProfile: View {
    @EnvironmentObject private var model: NativeAppModel
    @State private var notifications = false
    @State private var showingCommunity = false
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    HStack { Spacer(); Button { notifications = true } label: { Image(systemName: model.unread > 0 ? "bell.badge.fill" : "bell") }.foregroundStyle(Look.gold) }.padding(.top, 8)
                    LastCallAvatar().frame(width: 92, height: 92).clipShape(Circle()).overlay(Circle().stroke(Look.gold, lineWidth: 2))
                    Text(model.profile?.publicName ?? model.user?.email ?? "LAST CALL member").font(.system(size: 26, weight: .bold, design: .serif))
                    if let username = model.profile?.username, !username.isEmpty { Text("@\(username)").font(.system(size: 9)).foregroundStyle(Look.gold) }
                    Text(model.profile?.bio ?? "Behind the bar. Part of the LAST CALL community.").font(.system(size: 11, design: .serif)).foregroundStyle(Look.muted).multilineTextAlignment(.center)
                    HStack(spacing: 10) { Stat(value: "—", label: "STORIES"); Stat(value: "—", label: "FOLLOWERS"); Stat(value: "—", label: "FOLLOWING") }
                    VStack(spacing: 9) {
                        Button("THE COMMUNITY") { showingCommunity = true }.buttonStyle(PrimaryButton())
                        Button("SIGN OUT") { model.signOut() }.buttonStyle(OutlineButton())
                    }
                }.padding(18)
            }.background(Look.black.ignoresSafeArea()).foregroundStyle(Look.cream).navigationTitle("PROFILE").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $notifications) { NativeNotifications() }
            .sheet(isPresented: $showingCommunity) { NativeCommunity() }
            .task { await model.refreshAccount() }
        }
    }
}

struct NativeNotifications: View {
    @EnvironmentObject private var model: NativeAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var items: [NotificationRow] = []
    @State private var loading = true
    var body: some View {
        NavigationStack {
            List {
                if loading { ProgressView().tint(Look.gold).listRowBackground(Look.black) }
                if !loading && items.isEmpty { Text("You're all caught up.").foregroundStyle(Look.muted).listRowBackground(Look.black) }
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: item.type)).foregroundStyle(Look.gold).frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) { Text(title(for: item.type)).font(.system(size: 12, weight: .semibold, design: .serif)); Text(item.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 8)).foregroundStyle(Look.muted) }
                        Spacer(); if item.readAt == nil { Circle().fill(Look.gold).frame(width: 7, height: 7) }
                    }.listRowBackground(Look.card)
                }
            }.scrollContentBackground(.hidden).background(Look.black).foregroundStyle(Look.cream).navigationTitle("NOTIFICATIONS").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await load() }.refreshable { await load() }
        }
    }
    private func load() async { guard let token = model.token, let id = model.user?.id else { loading = false; return }; do { items = try await LastCallAPI.shared.fetchNotifications(userID: id, accessToken: token); if items.contains(where: { $0.readAt == nil }) { try? await LastCallAPI.shared.markNotificationsRead(userID: id, accessToken: token); await model.refreshAccount() } } catch {}; loading = false }
    private func icon(for type: String) -> String { if type.lowercased().contains("message") { return "message.fill" }; if type.lowercased().contains("follow") { return "person.badge.plus" }; if type.lowercased().contains("reaction") || type.lowercased().contains("beer") { return "mug.fill" }; return "bell.fill" }
    private func title(for type: String) -> String { switch type.lowercased() { case let value where value.contains("message"): return "You have a new message."; case let value where value.contains("follow"): return "Someone followed you."; case let value where value.contains("reaction"), let value where value.contains("beer"): return "Someone raised a pint to your story."; default: return "You have a new LAST CALL notification." } }
}

struct Stat: View { let value: String; let label: String; var body: some View { VStack(spacing: 3) { Text(value).font(.system(size: 18, weight: .bold, design: .serif)); Text(label).font(.system(size: 6, weight: .bold)).tracking(1).foregroundStyle(Look.muted) }.frame(maxWidth: .infinity).padding(.vertical, 13).background(Look.card).clipShape(RoundedRectangle(cornerRadius: 10)) } }
