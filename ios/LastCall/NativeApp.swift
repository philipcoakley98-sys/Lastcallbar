import PhotosUI
import SwiftUI
import UIKit

enum AuthMode {
  case signIn
  case signUp
}

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
  @Published var stories: [NativeStory] = []
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
    if let auth = await LastCallAPI.shared.restoreSession(),
      let accessToken = auth.accessToken,
      let signedInUser = auth.user
    {
      token = accessToken
      user = signedInUser
      signedIn = true
      await refreshAccount()
    }
    await refreshStories()
  }

  func refreshStories() async {
    do {
      let remote = try await LastCallAPI.shared.fetchPublishedStories()
      let ids = remote.map(\.id)
      let reactionCounts =
        (try? await LastCallAPI.shared.fetchReactionCounts(
          storyIDs: ids,
          accessToken: token ?? ""
        )) ?? [:]
      let commentCounts =
        (try? await LastCallAPI.shared.fetchCommentCounts(
          storyIDs: ids,
          accessToken: token
        )) ?? [:]
      let authorIDs = Array(Set(remote.compactMap(\.authorId)))
      let profiles =
        (try? await LastCallAPI.shared.fetchProfiles(
          ids: authorIDs,
          accessToken: token ?? ""
        )) ?? []
      let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

      stories = remote.map { remoteStory in
        NativeStory(
          remote: remoteStory,
          profile: remoteStory.authorId.flatMap { profilesByID[$0] },
          reactions: reactionCounts[remoteStory.id] ?? 0,
          comments: commentCounts[remoteStory.id] ?? 0
        )
      }
    } catch {
      error = "Stories could not be refreshed just now."
    }
    refreshID = UUID()
  }

  func refreshAccount() async {
    guard let accessToken = token, let userID = user?.id else { return }
    do {
      profile = try await LastCallAPI.shared.fetchProfile(userID: userID, accessToken: accessToken)
      reactions = try await LastCallAPI.shared.fetchReactionStoryIDs(
        userID: userID, accessToken: accessToken)
      let notifications = try await LastCallAPI.shared.fetchNotifications(
        userID: userID, accessToken: accessToken)
      unread = notifications.filter { $0.readAt == nil }.count
    } catch {
      // Keep the valid session even when optional account data is unavailable.
    }
  }

  func signIn(_ email: String, _ password: String) async {
    do {
      let auth = try await LastCallAPI.shared.signIn(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
        password: password
      )
      guard let accessToken = auth.accessToken, let signedInUser = auth.user else {
        throw LastCallAPIError.server("Sign in did not return a session.")
      }
      token = accessToken
      user = signedInUser
      signedIn = true
      showAuth = false
      await refreshAccount()
      await refreshStories()
    } catch {
      error = friendlyError(error)
    }
  }

  func signUp(_ email: String, _ password: String, _ name: String) async {
    do {
      let auth = try await LastCallAPI.shared.signUp(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
        password: password,
        displayName: name.nilIfEmpty
      )
      if let accessToken = auth.accessToken, let signedInUser = auth.user {
        token = accessToken
        user = signedInUser
        signedIn = true
        showAuth = false
        await refreshAccount()
      } else {
        error =
          "Account created. Check your email to confirm your address, then sign in to LAST CALL."
      }
    } catch {
      error = friendlyError(error)
    }
  }

  func signOut() {
    LastCallAPI.shared.signOut()
    token = nil
    user = nil
    profile = nil
    signedIn = false
    reactions.removeAll()
    unread = 0
    tab = .home
    stories.removeAll()
  }

  func react(_ story: NativeStory) async {
    guard let accessToken = token, let userID = user?.id else {
      authMode = .signIn
      showAuth = true
      return
    }
    do {
      let alreadyReacted = reactions.contains(story.id)
      _ = try await LastCallAPI.shared.toggleBeerReaction(
        storyID: story.id,
        userID: userID,
        accessToken: accessToken,
        reacted: alreadyReacted
      )
      if alreadyReacted {
        reactions.remove(story.id)
      } else {
        reactions.insert(story.id)
      }
      await refreshStories()
    } catch {
      error = "That reaction could not be saved."
    }
  }

  func submit(
    title: String,
    body: String,
    category: String,
    city: String,
    country: String,
    anonymous: Bool,
    imageData: Data?
  ) async -> Bool {
    guard let accessToken = token, let userID = user?.id else {
      authMode = .signIn
      showAuth = true
      return false
    }
    do {
      var imageURL: URL?
      if let imageData {
        guard let jpeg = UIImage(data: imageData)?.jpegData(compressionQuality: 0.82) else {
          throw LastCallAPIError.server("That image could not be prepared.")
        }
        imageURL = try await LastCallAPI.shared.uploadStoryImage(
          jpeg: jpeg,
          userID: userID,
          accessToken: accessToken
        )
      }
      try await LastCallAPI.shared.insertStory(
        title: title,
        body: body,
        category: category,
        city: city,
        country: country,
        anonymous: anonymous,
        imageURL: imageURL,
        accessToken: accessToken,
        userID: userID
      )
      return true
    } catch {
      error = "Your story could not be sent just now."
      return false
    }
  }

  private func friendlyError(_ error: Error) -> String {
    let message = error.localizedDescription
    if message.contains("Invalid login credentials") {
      return "That email or password was not recognised."
    }
    if message.contains("Email not confirmed") {
      return "Please confirm your email before signing in."
    }
    if message.lowercased().contains("already registered") {
      return "That email already has a LAST CALL account. Try signing in."
    }
    return message
  }
}

enum NativeTab: String, CaseIterable {
  case home = "Home"
  case discover = "Explore"
  case write = "Write"
  case messages = "Messages"
  case profile = "Profile"
}

struct NativeRootView: View {
  @EnvironmentObject private var model: NativeAppModel

  var body: some View {
    Group {
      if model.session {
        TabView(selection: $model.tab) {
          CommunityHome()
            .tag(NativeTab.home)
            .tabItem { Label("Home", systemImage: "house.fill") }
          ExploreView()
            .tag(NativeTab.discover)
            .tabItem { Label("Explore", systemImage: "safari") }
          NativeWrite()
            .tag(NativeTab.write)
            .tabItem { Label("Write", systemImage: "plus.circle.fill") }
          LastCallMessages()
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
    .sheet(isPresented: $model.showAuth) {
      NativeAuth(mode: $model.authMode)
    }
    .alert(
      "LAST CALL",
      isPresented: Binding(
        get: { model.error != nil },
        set: { if !$0 { model.error = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.error ?? "")
    }
  }
}

struct NativeStory: Identifiable, Hashable {
  let id: UUID
  let title: String
  let body: String
  let author: String
  let authorAvatarURL: URL?
  let location: String
  let category: String
  let reactions: Int
  let comments: Int
  let imageURL: URL?
  let isSample: Bool

  init(
    id: UUID = UUID(),
    title: String,
    body: String,
    author: String,
    authorAvatarURL: URL?,
    location: String,
    category: String,
    reactions: Int,
    comments: Int,
    imageURL: URL?,
    isSample: Bool = false
  ) {
    self.id = id
    self.title = title
    self.body = body
    self.author = author
    self.authorAvatarURL = authorAvatarURL
    self.location = location
    self.category = category
    self.reactions = reactions
    self.comments = comments
    self.imageURL = imageURL
    self.isSample = isSample
  }

  init(remote: RemoteStory, profile: ProfileRow?, reactions: Int, comments: Int) {
    self.init(
      id: remote.id,
      title: remote.title,
      body: remote.body,
      author: remote.anonymousName ?? profile?.publicName ?? "LAST CALL member",
      authorAvatarURL: profile?.avatarURL.flatMap(URL.init(string:)),
      location: remote.location.isEmpty ? "Worldwide" : remote.location,
      category: remote.category,
      reactions: reactions,
      comments: comments,
      imageURL: remote.imageURL.flatMap(URL.init(string:))
    )
  }
}

struct NativeHeader: View {
  @EnvironmentObject private var model: NativeAppModel

  var body: some View {
    HStack {
      Text("LAST CALL")
        .font(.system(size: 15, weight: .bold, design: .serif))
        .tracking(2.4)
      Spacer()
      Button {
        model.tab = .discover
      } label: {
        Image(systemName: "magnifyingglass")
      }
      if model.session {
        Button {
          model.tab = .profile
        } label: {
          ProfileAvatar(profile: model.profile, size: 27)
        }
      }
    }
    .foregroundStyle(Look.cream)
    .padding(.top, 6)
  }
}

struct NativeWrite: View {
  @EnvironmentObject private var model: NativeAppModel
  @State private var title = ""
  @State private var bodyText = ""
  @State private var category = "Closing Time"
  @State private var city = ""
  @State private var country = ""
  @State private var anonymous = true
  @State private var sending = false
  @State private var done = false
  @State private var photo: PhotosPickerItem?
  @State private var imageData: Data?

  let categories = ["Closing Time", "After Hours", "Bar Wisdom", "Staff Hours"]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Text("Tell us your story")
            .font(.system(size: 31, weight: .bold, design: .serif))
          Text("Funny, strange, heartwarming, unforgettable — whatever stayed with you.")
            .font(.system(size: 12, design: .serif))
            .foregroundStyle(Look.muted)
          TextField("Story title", text: $title)
            .textFieldStyle(LCField())
          TextEditor(text: $bodyText)
            .frame(minHeight: 230)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Look.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Look.line))
          Picker("Category", selection: $category) {
            ForEach(categories, id: \.self, content: Text.init)
          }
          .pickerStyle(.menu)
          HStack {
            TextField("City", text: $city).textFieldStyle(LCField())
            TextField("Country", text: $country).textFieldStyle(LCField())
          }
          Toggle("Post anonymously", isOn: $anonymous).tint(Look.green)
          PhotosPicker(selection: $photo, matching: .images) {
            Label(imageData == nil ? "ADD STORY PHOTO" : "PHOTO READY", systemImage: "photo")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(Look.gold)
              .padding(11)
              .frame(maxWidth: .infinity)
              .background(Look.card)
              .clipShape(RoundedRectangle(cornerRadius: 9))
          }
          .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { imageData = try? await item.loadTransferable(type: Data.self) }
          }
          if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .frame(height: 180)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          Button(sending ? "SENDING…" : "SUBMIT STORY →") {
            sending = true
            Task {
              let success = await model.submit(
                title: title,
                body: bodyText,
                category: category,
                city: city,
                country: country,
                anonymous: anonymous,
                imageData: imageData
              )
              sending = false
              if success {
                done = true
                title = ""
                bodyText = ""
                city = ""
                country = ""
                imageData = nil
                photo = nil
              }
            }
          }
          .buttonStyle(PrimaryButton())
          .disabled(sending || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          if done {
            Text("Thanks — your story has been sent for review.")
              .font(.system(size: 9, weight: .semibold))
              .foregroundStyle(Look.gold)
          }
        }
        .padding(13)
      }
      .background(Look.black.ignoresSafeArea())
      .foregroundStyle(Look.cream)
      .navigationBarHidden(true)
    }
  }
}

struct NativeImage: View {
  let url: URL?
  var body: some View {
    AsyncImage(url: url) { phase in
      switch phase {
      case .success(let image):
        image.resizable().scaledToFill()
      default:
        ZStack {
          Look.card.ignoresSafeArea()
          LastCallAvatar().padding(22)
        }
      }
    }
    .clipped()
  }
}

struct PrimaryButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 8, weight: .bold))
      .tracking(1)
      .foregroundStyle(Look.black)
      .padding(.horizontal, 13)
      .padding(.vertical, 9)
      .background(Look.gold)
      .clipShape(RoundedRectangle(cornerRadius: 7))
      .opacity(configuration.isPressed ? 0.75 : 1)
  }
}

struct OutlineButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 7, weight: .bold))
      .tracking(0.8)
      .foregroundStyle(Look.gold)
      .padding(.horizontal, 9)
      .padding(.vertical, 7)
      .background(Look.card)
      .clipShape(RoundedRectangle(cornerRadius: 7))
      .overlay(RoundedRectangle(cornerRadius: 7).stroke(Look.gold.opacity(0.35)))
      .opacity(configuration.isPressed ? 0.7 : 1)
  }
}

struct LCField: TextFieldStyle {
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .padding(11)
      .background(Look.card)
      .foregroundStyle(Look.cream)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(Look.line))
  }
}

struct Look {
  static let black = Color(red: 0.03, green: 0.03, blue: 0.025)
  static let card = Color(red: 0.08, green: 0.075, blue: 0.065)
  static let cream = Color(red: 0.95, green: 0.92, blue: 0.85)
  static let gold = Color(red: 0.84, green: 0.70, blue: 0.34)
  static let green = Color(red: 0.12, green: 0.36, blue: 0.22)
  static let muted = Color(red: 0.62, green: 0.59, blue: 0.52)
  static let line = Color.white.opacity(0.10)
}
