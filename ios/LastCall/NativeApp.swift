import PhotosUI
import SwiftUI
import UIKit

enum AuthMode { case signIn, signUp }

@main
struct LastCallNativeApp: App {
  @StateObject private var model = NativeAppModel()
  var body: some Scene {
    WindowGroup {
      NativeRootView().environmentObject(model).preferredColorScheme(.dark).task {
        await model.bootstrap()
      }
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
    if let auth = await LastCallAPI.shared.restoreSession(), let accessToken = auth.accessToken,
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
        (try? await LastCallAPI.shared.fetchReactionCounts(storyIDs: ids, accessToken: token ?? ""))
        ?? [:]
      let commentCounts =
        (try? await LastCallAPI.shared.fetchCommentCounts(storyIDs: ids, accessToken: token)) ?? [:]
      let authorIDs = Array(Set(remote.compactMap(\.authorId)))
      let profiles =
        (try? await LastCallAPI.shared.fetchProfiles(ids: authorIDs, accessToken: token ?? ""))
        ?? []
      let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
      stories = remote.map { remoteStory in
        NativeStory(
          remote: remoteStory, profile: remoteStory.authorId.flatMap { profilesByID[$0] },
          reactions: reactionCounts[remoteStory.id] ?? 0,
          comments: commentCounts[remoteStory.id] ?? 0)
      }
    } catch {
      self.error = "Stories could not be refreshed just now."
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
    } catch {}
  }

  func signIn(_ email: String, _ password: String) async {
    do {
      let auth = try await LastCallAPI.shared.signIn(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
      guard let accessToken = auth.accessToken, let signedInUser = auth.user else {
        throw LastCallAPIError.server("Sign in did not return a session.")
      }
      token = accessToken
      user = signedInUser
      signedIn = true
      showAuth = false
      await refreshAccount()
      await refreshStories()
    } catch let caughtError {
      self.error = friendlyError(caughtError)
    }
  }

  func signUp(_ email: String, _ password: String, _ name: String) async {
    do {
      let auth = try await LastCallAPI.shared.signUp(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password,
        displayName: name.nilIfEmpty)
      if let accessToken = auth.accessToken, let signedInUser = auth.user {
        token = accessToken
        user = signedInUser
        signedIn = true
        showAuth = false
        await refreshAccount()
      } else {
        self.error =
          "Account created. Check your email to confirm your address, then sign in to LAST CALL."
      }
    } catch let caughtError {
      self.error = friendlyError(caughtError)
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
        storyID: story.id, userID: userID, accessToken: accessToken, reacted: alreadyReacted)
      if alreadyReacted { reactions.remove(story.id) } else { reactions.insert(story.id) }
      await refreshStories()
    } catch { self.error = "That reaction could not be saved." }
  }

  func submit(
    title: String, body: String, category: String, city: String, country: String, anonymous: Bool,
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
          jpeg: jpeg, userID: userID, accessToken: accessToken)
      }
      try await LastCallAPI.shared.insertStory(
        title: title, body: body, category: category, city: city, country: country,
        anonymous: anonymous, imageURL: imageURL, accessToken: accessToken, userID: userID)
      return true
    } catch {
      self.error = "Your story could not be sent just now."
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
        Group {
          switch model.tab {
          case .home: CommunityHome()
          case .discover: ExploreView()
          case .write: NativeWrite()
          case .messages: LastCallMessages()
          case .profile: LastCallProfileScreen()
          }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
          LastCallBottomBar()
        }
      } else {
        LockedHome()
      }
    }
    .background(Look.black.ignoresSafeArea())
    .sheet(isPresented: $model.showAuth) { NativeAuth(mode: $model.authMode) }
    .alert(
      "LAST CALL",
      isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.error ?? "")
    }
  }
}

struct LastCallBottomBar: View {
  @EnvironmentObject private var model: NativeAppModel

  var body: some View {
    HStack(spacing: 0) {
      bottomItem(.home, icon: "house.fill", label: "Home")
      bottomItem(.discover, icon: "safari", label: "Explore")
      Button {
        model.tab = .write
      } label: {
        ZStack {
          Circle().fill(.white).frame(width: 58, height: 58)
          Image(systemName: "plus")
            .font(.system(size: 25, weight: .medium))
            .foregroundStyle(Look.black)
        }
      }
      .frame(maxWidth: .infinity)
      bottomItem(.messages, icon: "message.fill", label: "Messages", badge: model.unread)
      bottomItem(.profile, icon: "person.fill", label: "Profile")
    }
    .frame(height: 70)
    .padding(.horizontal, 7)
    .padding(.top, 4)
    .background(.black.opacity(0.96))
    .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
  }

  @ViewBuilder
  private func bottomItem(_ tab: NativeTab, icon: String, label: String, badge: Int = 0) -> some View {
    Button { model.tab = tab } label: {
      VStack(spacing: 3) {
        ZStack(alignment: .topTrailing) {
          Image(systemName: model.tab == tab ? icon : icon.replacingOccurrences(of: ".fill", with: ""))
            .font(.system(size: 20, weight: .medium))
          if badge > 0 {
            Text(badge > 9 ? "9+" : "\(badge)")
              .font(.system(size: 7, weight: .bold))
              .foregroundStyle(.white)
              .padding(3)
              .background(.red)
              .clipShape(Circle())
              .offset(x: 8, y: -7)
          }
        }
        Text(label).font(.system(size: 9, weight: model.tab == tab ? .bold : .medium))
      }
      .foregroundStyle(model.tab == tab ? .white : .white.opacity(0.58))
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.plain)
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
    id: UUID = UUID(), title: String, body: String, author: String, authorAvatarURL: URL?,
    location: String, category: String, reactions: Int, comments: Int, imageURL: URL?,
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
      id: remote.id, title: remote.title, body: remote.body,
      author: remote.anonymousName ?? profile?.publicName ?? "LAST CALL member",
      authorAvatarURL: profile?.avatarURL.flatMap(URL.init(string:)),
      location: remote.location.isEmpty ? "Worldwide" : remote.location, category: remote.category,
      reactions: reactions, comments: comments, imageURL: remote.imageURL.flatMap(URL.init(string:))
    )
  }
}

struct NativeHeader: View {
  @EnvironmentObject private var model: NativeAppModel
  var body: some View {
    HStack {
      Text("LAST CALL").font(.system(size: 15, weight: .bold, design: .serif)).tracking(2.4)
      Spacer()
      Button { model.tab = .discover } label: { Image(systemName: "magnifyingglass") }
      if model.session {
        Button { model.tab = .profile } label: { ProfileAvatar(profile: model.profile, size: 27) }
      }
    }.foregroundStyle(Look.cream).padding(.top, 6)
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
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 14) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Write a story").font(.system(size: 29, weight: .bold, design: .serif))
              Text("Real nights. Real people. Last call.")
                .font(.system(size: 11, design: .serif)).foregroundStyle(Look.muted)
            }
            Spacer()
          }

          TextField("Story title", text: $title)
            .textFieldStyle(LCField())

          ZStack(alignment: .topLeading) {
            TextEditor(text: $bodyText)
              .frame(minHeight: 210)
              .scrollContentBackground(.hidden)
              .padding(7)
            if bodyText.isEmpty {
              Text("What happened behind the bar?")
                .foregroundStyle(Look.muted)
                .padding(.horizontal, 13)
                .padding(.top, 15)
                .allowsHitTesting(false)
            }
          }
          .background(Look.card)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .overlay(RoundedRectangle(cornerRadius: 12).stroke(Look.line))

          PhotosPicker(selection: $photo, matching: .images) {
            HStack(spacing: 10) {
              Image(systemName: "camera")
              Text(imageData == nil ? "Add a photo (optional)" : "Photo added")
              Spacer()
              Image(systemName: imageData == nil ? "plus" : "checkmark")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(15)
            .background(Look.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Look.line))
          }
          .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { imageData = try? await item.loadTransferable(type: Data.self) }
          }

          if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
              .resizable().scaledToFill().frame(height: 175).clipShape(RoundedRectangle(cornerRadius: 12))
          }

          VStack(spacing: 10) {
            HStack {
              Image(systemName: "mappin.and.ellipse")
              TextField("Add location (optional)", text: $city)
              Spacer()
            }
            .foregroundStyle(.white)
            .padding(13)
            .background(Look.card)
            .clipShape(RoundedRectangle(cornerRadius: 11))

            HStack {
              Image(systemName: "tag")
              Picker("Category", selection: $category) {
                ForEach(categories, id: \.self) { Text($0) }
              }
              .pickerStyle(.menu)
              Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .background(Look.card)
            .clipShape(RoundedRectangle(cornerRadius: 11))
          }

          Toggle("Post anonymously", isOn: $anonymous)
            .tint(Look.green)
            .font(.system(size: 12, weight: .medium))

          Button {
            sending = true
            Task {
              let success = await model.submit(
                title: title, body: bodyText, category: category, city: city, country: country,
                anonymous: anonymous, imageData: imageData)
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
          } label: {
            Text(sending ? "Posting…" : "Post story")
              .frame(maxWidth: .infinity).frame(height: 52)
          }
          .buttonStyle(PrimaryButton())
          .disabled(sending || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          if done {
            Text("Your story has been sent for review.")
              .font(.system(size: 10, weight: .semibold)).foregroundStyle(Look.gold)
          }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 18)
      }
      .background(Look.black.ignoresSafeArea())
      .foregroundStyle(Look.cream)
      .toolbar(.hidden, for: .navigationBar)
    }
  }
}

struct NativeImage: View {
  let url: URL?
  var body: some View {
    AsyncImage(url: url) { phase in
      switch phase {
      case .success(let image): image.resizable().scaledToFill()
      default:
        ZStack { Look.card.ignoresSafeArea(); LastCallAvatar().padding(22) }
      }
    }.clipped()
  }
}

struct PrimaryButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .bold))
      .foregroundStyle(Look.black)
      .background(Look.gold)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .opacity(configuration.isPressed ? 0.75 : 1)
  }
}

struct OutlineButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 7, weight: .bold)).tracking(0.8).foregroundStyle(
      Look.gold
    ).padding(.horizontal, 9).padding(.vertical, 7).background(Look.card).clipShape(
      RoundedRectangle(cornerRadius: 7)
    ).overlay(RoundedRectangle(cornerRadius: 7).stroke(Look.gold.opacity(0.35))).opacity(
      configuration.isPressed ? 0.7 : 1)
  }
}

struct LCField: TextFieldStyle {
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration.padding(11).background(Look.card).foregroundStyle(Look.cream).clipShape(
      RoundedRectangle(cornerRadius: 8)
    ).overlay(RoundedRectangle(cornerRadius: 8).stroke(Look.line))
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

struct LastCallProfileScreen: View {
  @EnvironmentObject private var model: NativeAppModel
  @State private var tab=0
  @State private var stats=ProfileStats(stories:0,followers:0,following:0)
  @State private var mine:[NativeStory]=[]
  @State private var loading=true
  @State private var notifications=false
  @State private var editing=false
  private let tabs=["STORIES","REACTIONS","ABOUT"]
  var body: some View {
    ScrollView(showsIndicators:false) {
      VStack(spacing:0) {
        ZStack(alignment:.bottom) {
          Image("LastCallWelcome").resizable().scaledToFill().frame(height:180).clipped()
          LinearGradient(colors:[.clear,.black.opacity(0.95)],startPoint:.center,endPoint:.bottom)
          HStack { Text("LAST CALL").font(.system(size:11,weight:.black,design:.serif)).tracking(2.5); Spacer(); Button { notifications=true } label:{ Image(systemName:model.unread>0 ? "bell.badge.fill":"bell.fill") } }
            .foregroundStyle(.white).padding(16)
        }
        VStack(spacing:10) {
          LastCallProfilePhotoPicker().offset(y:-38).padding(.bottom,-30)
          Text(model.profile?.publicName ?? model.user?.email ?? "LAST CALL member").font(.system(size:28,weight:.bold,design:.serif)).multilineTextAlignment(.center)
          if let u=model.profile?.username,!u.isEmpty { Text("@\(u)").font(.system(size:10,weight:.semibold)).foregroundStyle(Look.gold) }
          if let b=model.profile?.bio,!b.isEmpty { Text(b).font(.system(size:12,design:.serif)).foregroundStyle(Look.muted).multilineTextAlignment(.center).padding(.horizontal,28) }
          HStack { stat("\(stats.stories)","STORIES"); stat("\(stats.followers)","FOLLOWERS"); stat("\(stats.following)","FOLLOWING") }
          HStack(spacing:8) { Button("EDIT PROFILE"){editing=true}.buttonStyle(PrimaryButton()); Button("COMMUNITY"){model.tab = .discover}.buttonStyle(OutlineButton()) }.padding(.horizontal,18)
        }.padding(.horizontal,12)
        HStack(spacing:0) { ForEach(Array(tabs.enumerated()),id:\.offset){ i,t in Button { withAnimation{tab=i} } label:{ VStack(spacing:8){ Text(t).font(.system(size:8,weight:.bold)).tracking(1).foregroundStyle(tab==i ? Look.gold:Look.muted); Rectangle().fill(tab==i ? Look.gold:Look.line).frame(height:tab==i ? 2:1) }.frame(maxWidth:.infinity) }.buttonStyle(.plain) } }.padding(.top,24).padding(.horizontal,16)
        Group { if tab==0 { storyList(mine) } else if tab==1 { storyList(model.stories.filter{model.reactions.contains($0.id)}) } else { about } }.padding(16)
      }.padding(.bottom,24)
    }.background(Look.black.ignoresSafeArea()).foregroundStyle(Look.cream)
      .sheet(isPresented:$notifications){NativeNotifications()}.sheet(isPresented:$editing){EditProfileSheet(profile:model.profile){model.profile=$0}}
      .task{await load()}.refreshable{await load()}
  }
  private func stat(_ v:String,_ l:String)->some View { VStack(spacing:3){Text(v).font(.system(size:18,weight:.bold,design:.serif));Text(l).font(.system(size:7,weight:.bold)).tracking(1).foregroundStyle(Look.muted)}.frame(maxWidth:.infinity) }
  @ViewBuilder private func storyList(_ list:[NativeStory])->some View { if list.isEmpty { VStack(spacing:8){Image(systemName:"book.closed").foregroundStyle(Look.gold);Text(tab==1 ? "NO REACTIONS YET":"NO STORIES YET").font(.system(size:9,weight:.bold)).tracking(1);Text(tab==1 ? "Stories you raise a glass to will appear here.":"Your approved stories will live here.").font(.system(size:10,design:.serif)).foregroundStyle(Look.muted)}.frame(maxWidth:.infinity).padding(.vertical,30) } else { ForEach(list){ story in VStack(alignment:.leading,spacing:7){NativeImage(url:story.imageURL).frame(height:180).clipShape(RoundedRectangle(cornerRadius:12));Text(story.category.uppercased()).font(.system(size:7,weight:.bold)).foregroundStyle(Look.gold);Text(story.title).font(.system(size:20,weight:.bold,design:.serif));Text(story.body).font(.system(size:11,design:.serif)).foregroundStyle(Look.muted).lineLimit(3)}.padding(13).background(Look.card).clipShape(RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(Look.line)) } } }
  private var about:some View { VStack(alignment:.leading,spacing:12){Text("ABOUT").font(.system(size:8,weight:.bold)).tracking(1.3).foregroundStyle(Look.gold);Text(model.profile?.bio?.isEmpty == false ? model.profile!.bio! : "This member hasn't added an about yet.").font(.system(size:13,design:.serif)).foregroundStyle(Look.muted);Divider().overlay(Look.line);Button("SIGN OUT"){model.signOut()}.buttonStyle(OutlineButton())}.padding(15).background(Look.card).clipShape(RoundedRectangle(cornerRadius:14)) }
  private func load() async { await model.refreshAccount(); guard let token=model.token,let id=model.user?.id else {loading=false;return}; do { stats=try await LastCallAPI.shared.fetchProfileStats(userID:id,accessToken:token); let r=try await LastCallAPI.shared.fetchPublishedStories(); let m=r.filter{$0.authorId==id}; let cc=(try? await LastCallAPI.shared.fetchCommentCounts(storyIDs:m.map(\.id),accessToken:token)) ?? [:]; let rc=(try? await LastCallAPI.shared.fetchReactionCounts(storyIDs:m.map(\.id),accessToken:token)) ?? [:]; mine=m.map{NativeStory(remote:$0,profile:model.profile,reactions:rc[$0.id] ?? 0,comments:cc[$0.id] ?? 0)} } catch { model.error="Your profile could not be refreshed just now." }; loading=false }
}
