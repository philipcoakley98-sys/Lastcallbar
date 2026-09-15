import SwiftUI

struct CommunityHome: View {
  @EnvironmentObject private var model: NativeAppModel
  @State private var selected: NativeStory?
  @State private var showNotifications = false

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(spacing: 0) {
          topBar
          storyStrip
          composer
          feed
        }
      }
      .background(
        LinearGradient(
          colors: [Color(red: 0.055, green: 0.08, blue: 0.065), Look.black],
          startPoint: .top,
          endPoint: .center
        ).ignoresSafeArea()
      )
      .foregroundStyle(Look.cream)
      .navigationBarHidden(true)
      .refreshable { await model.refreshStories() }
      .sheet(item: $selected) { NativeStoryDetail(story: $0) }
      .sheet(isPresented: $showNotifications) { NativeNotifications() }
      .task { await model.refreshStories() }
    }
  }

  private var topBar: some View {
    HStack(spacing: 12) {
      Button { model.tab = .profile } label: {
        ProfileAvatar(profile: model.profile, size: 40)
          .overlay(Circle().stroke(Look.gold, lineWidth: 1.5))
      }
      Spacer()
      VStack(spacing: -1) {
        Text("LAST CALL")
          .font(.system(size: 22, weight: .black, design: .rounded))
          .tracking(-1.1)
        CheersPintsMarkForFeed()
          .frame(width: 36, height: 19)
          .foregroundStyle(.white)
      }
      Spacer()
      HStack(spacing: 17) {
        Button { model.tab = .discover } label: {
          Image(systemName: "magnifyingglass")
        }
        Button { showNotifications = true } label: {
          ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")
            if model.unread > 0 {
              Circle().fill(Look.gold).frame(width: 7, height: 7).offset(x: 2, y: -1)
            }
          }
        }
      }
    }
    .font(.system(size: 19, weight: .medium))
    .padding(.horizontal, 15)
    .padding(.top, 8)
    .padding(.bottom, 12)
  }

  private var storyStrip: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 13) {
        Button { model.tab = .write } label: {
          VStack(spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
              Circle()
                .fill(Look.card)
                .frame(width: 65, height: 65)
                .overlay(Circle().stroke(Look.gold, lineWidth: 2))
              ProfileAvatar(profile: model.profile, size: 57)
                .overlay(Circle().stroke(Look.black, lineWidth: 2))
              Circle()
                .fill(.white)
                .frame(width: 21, height: 21)
                .overlay(Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(Look.black))
                .offset(x: 1, y: 1)
            }
            Text("Your story")
              .font(.system(size: 9, weight: .semibold))
              .foregroundStyle(Look.cream)
              .lineLimit(1)
          }
          .frame(width: 72)
        }
        .buttonStyle(.plain)

        ForEach(Array(model.stories.prefix(8))) { story in
          Button { selected = story } label: {
            VStack(spacing: 5) {
              Circle()
                .stroke(Look.gold, lineWidth: 2)
                .frame(width: 65, height: 65)
                .overlay {
                  if let avatar = story.authorAvatarURL {
                    NativeImage(url: avatar).clipShape(Circle()).padding(3)
                  } else {
                    LastCallAvatar().padding(8)
                  }
                }
              Text(story.author)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Look.cream)
                .lineLimit(1)
            }
            .frame(width: 72)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 15)
    }
    .padding(.bottom, 12)
  }

  private var composer: some View {
    Button { model.tab = .write } label: {
      HStack(spacing: 10) {
        ProfileAvatar(profile: model.profile, size: 40)
        Text("What's on your mind?")
          .font(.system(size: 14, design: .rounded))
          .foregroundStyle(Look.muted)
        Spacer()
        Image(systemName: "photo.on.rectangle")
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(Look.gold)
      }
      .foregroundStyle(Look.cream)
      .padding(.horizontal, 13)
      .frame(height: 58)
      .background(Look.card)
      .clipShape(Capsule())
      .overlay(Capsule().stroke(Look.line))
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 14)
    .padding(.bottom, 10)
  }

  private var feed: some View {
    LazyVStack(spacing: 0) {
      if model.stories.isEmpty {
        VStack(alignment: .leading, spacing: 7) {
          Text("No published stories yet.")
            .font(.system(size: 16, weight: .semibold, design: .serif))
          Text("Be the first to share the craic behind the bar.")
            .font(.system(size: 12, design: .serif))
            .foregroundStyle(Look.muted)
          Button("WRITE A STORY") { model.tab = .write }
            .buttonStyle(PrimaryButton())
            .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
      } else {
        ForEach(model.stories) { story in
          CommunityPost(
            story: story,
            open: { selected = story },
            react: { Task { await model.react(story) } }
          )
          Divider().overlay(Look.line)
        }
      }
    }
  }
}

private struct CommunityPost: View {
  @EnvironmentObject private var model: NativeAppModel
  let story: NativeStory
  let open: () -> Void
  let react: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 9) {
        if let avatar = story.authorAvatarURL {
          NativeImage(url: avatar)
            .frame(width: 39, height: 39)
            .clipShape(Circle())
        } else {
          LastCallAvatar()
            .frame(width: 39, height: 39)
            .clipShape(Circle())
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(story.author).font(.system(size: 12, weight: .semibold))
          Text(story.location).font(.system(size: 8)).foregroundStyle(Look.muted)
        }
        Spacer()
        Image(systemName: "ellipsis")
          .foregroundStyle(Look.muted)
      }
      Text(story.title)
        .font(.system(size: 15, weight: .medium, design: .serif))
        .lineLimit(2)
      if !story.body.isEmpty {
        Text(story.body)
          .font(.system(size: 12, design: .serif))
          .foregroundStyle(Look.muted)
          .lineLimit(3)
      }
      Button(action: open) {
        NativeImage(url: story.imageURL)
          .frame(maxWidth: .infinity)
          .frame(height: 275)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      HStack(spacing: 22) {
        Button(action: react) {
          HStack(spacing: 5) {
            Image(systemName: model.reactions.contains(story.id) ? "heart.fill" : "heart")
            Text("\(story.reactions + (model.reactions.contains(story.id) ? 1 : 0))")
          }
        }
        Button(action: open) {
          HStack(spacing: 5) {
            Image(systemName: "bubble.right")
            Text("\(story.comments)")
          }
        }
        ShareLink(item: story.title) {
          Image(systemName: "paperplane")
        }
        Spacer()
        Image(systemName: "bookmark")
          .foregroundStyle(Look.muted)
      }
      .font(.system(size: 18))
      .foregroundStyle(Look.cream)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }
}

private struct CheersPintsMarkForFeed: View {
  var body: some View {
    HStack(spacing: -4) {
      FeedPint().rotationEffect(.degrees(-16))
      FeedPint().rotationEffect(.degrees(16))
    }
  }
}

private struct FeedPint: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 3)
      .stroke(.primary, lineWidth: 2)
      .frame(width: 12, height: 17)
  }
}
