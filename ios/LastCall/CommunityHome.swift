import SwiftUI

/// The signed-in Home / Feed from the approved LAST CALL app reference.
/// It is intentionally separate from the public welcome screen.
struct CommunityHome: View {
    @EnvironmentObject private var model: NativeAppModel
    @State private var selected: NativeStory?
    @State private var composerText = ""

    private let storyNames = ["Your story", "Conor", "Seán", "Jack", "Aoife", "Damo"]
    private let storyImages = [
        "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1527761939622-933c0a2a6a57?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1519671282429-b44660ead0a7?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=240&q=80"
    ]

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
            .background(Look.black.ignoresSafeArea())
            .foregroundStyle(Look.cream)
            .navigationBarHidden(true)
            .refreshable { await model.refreshStories() }
            .sheet(item: $selected) { story in
                NativeStoryDetail(story: story)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { model.tab = .profile } label: {
                Circle()
                    .fill(Look.green)
                    .frame(width: 38, height: 38)
                    .overlay(Text("LC").font(.system(size: 8, weight: .bold)))
            }
            Spacer()
            VStack(spacing: 1) {
                Text("LAST CALL")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .tracking(-0.8)
                CheersPintsMarkForFeed()
                    .frame(width: 34, height: 19)
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 16) {
                Button { model.tab = .discover } label: { Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .medium)) }
                Button { model.tab = .profile } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell").font(.system(size: 19, weight: .medium))
                        if model.unread > 0 {
                            Circle().fill(Look.gold).frame(width: 7, height: 7).offset(x: 2, y: -1)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var storyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 13) {
                ForEach(Array(storyNames.enumerated()), id: \.offset) { index, name in
                    VStack(spacing: 5) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .stroke(Look.gold, lineWidth: 2)
                                .frame(width: 65, height: 65)
                                .overlay {
                                    AsyncImage(url: URL(string: storyImages[index])) { phase in
                                        if case .success(let image) = phase {
                                            image.resizable().scaledToFill()
                                        } else {
                                            Look.card
                                        }
                                    }
                                    .clipShape(Circle())
                                    .padding(3)
                                }
                            if index == 0 {
                                Circle().fill(.white).frame(width: 23, height: 23)
                                    .overlay(Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(.black))
                                    .offset(x: 3, y: 3)
                            }
                        }
                        Text(name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Look.cream)
                            .lineLimit(1)
                    }
                    .frame(width: 72)
                }
            }
            .padding(.horizontal, 15)
        }
        .padding(.bottom, 12)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            Circle().fill(Look.green).frame(width: 40, height: 40)
                .overlay(Text("LC").font(.system(size: 8, weight: .bold)))
            Text("What's on your mind?")
                .font(.system(size: 14))
                .foregroundStyle(Look.muted)
            Spacer()
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 20))
                .foregroundStyle(Look.cream)
        }
        .padding(.horizontal, 13)
        .frame(height: 58)
        .background(Look.card)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Look.line))
        .padding(.horizontal, 14)
        .padding(.bottom, 9)
        .contentShape(Rectangle())
        .onTapGesture { model.tab = .write }
    }

    private var feed: some View {
        LazyVStack(spacing: 0) {
            if model.stories.isEmpty {
                Text("No stories yet. Be the first to share the craic.")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Look.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            } else {
                ForEach(model.stories) { story in
                    CommunityPost(story: story) {
                        selected = story
                    } react: {
                        Task { await model.react(story) }
                    }
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
                Circle().fill(Look.green).frame(width: 39, height: 39)
                    .overlay(Text("LC").font(.system(size: 8, weight: .bold)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(story.author == "SAMPLE" ? "Conor_Mc" : story.author)
                        .font(.system(size: 12, weight: .semibold))
                    Text(story.isSample ? "2h ago" : story.location)
                        .font(.system(size: 8))
                        .foregroundStyle(Look.muted)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundStyle(Look.cream)
            }

            Text(story.title)
                .font(.system(size: 15, weight: .medium, design: .serif))
                .lineLimit(2)

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
                        Text("\(story.reactions)")
                    }
                }
                Button(action: open) {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.right")
                        Text("\(story.comments)")
                    }
                }
                Image(systemName: "paperplane")
                Spacer()
                Image(systemName: "bookmark")
            }
            .font(.system(size: 18, weight: .regular))
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
