import SwiftUI

@main
struct LastCallApp: App {
    @StateObject private var model = LastCallModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

final class LastCallModel: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var stories = Story.samples
    @Published var isSignedIn = false
    @Published var showingWriteStory = false
}

enum AppTab: String, CaseIterable {
    case home = "Home"
    case discover = "Discover"
    case write = "Write"
    case messages = "Messages"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .discover: return "magnifyingglass"
        case .write: return "pencil.and.outline"
        case .messages: return "bubble.left.and.bubble.right.fill"
        case .profile: return "person.fill"
        }
    }
}

struct Story: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let body: String
    let author: String
    let location: String
    let category: String
    let reactions: Int
    let comments: Int
    let imageURL: URL?

    static let samples: [Story] = [
        Story(title: "Last night was one for the books", body: "Good friends, great drinks, and a story I’ll be telling for a long time. 🍻", author: "Coco98", location: "Dublin, Ireland", category: "After Hours", reactions: 124, comments: 12, imageURL: URL(string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1200&q=82")),
        Story(title: "Small pub, big conversations", body: "That’s the magic. Sometimes the quiet nights stay with you longest.", author: "DanielleR", location: "Galway, Ireland", category: "Bar Wisdom", reactions: 89, comments: 7, imageURL: URL(string: "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?auto=format&fit=crop&w=1200&q=82")),
        Story(title: "Nothing beats a full cold one", body: "A few close ones, good people, and a proper last call.", author: "ConorB", location: "Cork, Ireland", category: "Closing Time", reactions: 156, comments: 14, imageURL: URL(string: "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?auto=format&fit=crop&w=1200&q=82"))
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
                    StoryOfNightView(story: model.stories[0]) { selectedStory = model.stories[0] }
                    SectionHeading(title: "Top Stories", action: "See all")
                    ForEach(model.stories) { story in
                        StoryRow(story: story) { selectedStory = story }
                    }
                    CategoryStrip()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 28)
            }
            .background(LCTheme.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $selectedStory) { story in
                StoryDetailView(story: story)
            }
        }
    }
}

struct AppHeader: View {
    @EnvironmentObject private var model: LastCallModel

    var body: some View {
        HStack(spacing: 10) {
            Text("LAST CALL")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .tracking(2.6)
            Spacer()
            Button { model.selectedTab = .discover } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Search stories")
            Circle()
                .fill(LCTheme.green)
                .frame(width: 27, height: 27)
                .overlay(Text("LC").font(.system(size: 8, weight: .bold)))
        }
        .foregroundStyle(LCTheme.cream)
        .padding(.top, 8)
    }
}

struct HeroView: View {
    @EnvironmentObject private var model: LastCallModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: URL(string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1400&q=85"))
                .overlay(LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.88)], startPoint: .top, endPoint: .bottom))
            VStack(alignment: .leading, spacing: 8) {
                Text("IRISH ROOTS · WORLDWIDE STORIES")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(LCTheme.gold)
                Text("LAST CALL")
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .tracking(-2)
                Text("Stories From Behind the Bar")
                    .font(.system(size: 21, weight: .bold, design: .serif).italic())
                    .foregroundStyle(LCTheme.gold)
                Text("Funny. Strange. Heartwarming. Unforgettable.")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(LCTheme.cream.opacity(0.85))
                Button("WRITE A STORY →") { model.selectedTab = .write }
                    .buttonStyle(LCPrimaryButton())
                    .padding(.top, 4)
            }
            .padding(18)
        }
        .frame(height: 310)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LCTheme.gold.opacity(0.28), lineWidth: 1))
    }
}

struct StoryOfNightView: View {
    let story: Story
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                RemoteImage(url: story.imageURL)
                    .frame(width: 126)
                VStack(alignment: .leading, spacing: 7) {
                    Text("STORY OF THE NIGHT · LAST CALL")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(LCTheme.gold)
                    Text(story.title)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .multilineTextAlignment(.leading)
                    Text(story.body)
                        .font(.system(size: 9, design: .serif))
                        .foregroundStyle(LCTheme.muted)
                        .lineLimit(4)
                    Text("🍺 \(story.reactions)   ·   💬 \(story.comments)   ·   READ FULL STORY →")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(LCTheme.gold)
                }
                .padding(12)
                Spacer(minLength: 0)
            }
            .frame(height: 166)
            .background(LCTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LCTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct StoryRow: View {
    let story: Story
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RemoteImage(url: story.imageURL).frame(width: 78, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(story.category.uppercased())
                        .font(.system(size: 6, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(LCTheme.gold)
                    Text(story.title)
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text("\(story.author) · \(story.location)")
                        .font(.system(size: 7))
                        .foregroundStyle(LCTheme.muted)
                    Text("🍺 \(story.reactions)   💬 \(story.comments)")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(LCTheme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(LCTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LCTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeading: View {
    let title: String
    let action: String
    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title).font(.system(size: 20, weight: .bold, design: .serif))
            Spacer()
            Text(action.uppercased()).font(.system(size: 7, weight: .semibold)).tracking(1).foregroundStyle(LCTheme.gold)
        }
        .foregroundStyle(LCTheme.cream)
    }
}

struct CategoryStrip: View {
    let categories = ["Closing Time", "After Hours", "Bar Wisdom", "Staff Hours"]
    let icons = ["moon.stars.fill", "clock.fill", "lightbulb.fill", "person.2.fill"]
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("EXPLORE BY CATEGORY").font(.system(size: 8, weight: .bold)).tracking(1.3).foregroundStyle(LCTheme.gold)
            HStack(spacing: 5) {
                ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                    VStack(spacing: 5) {
                        Image(systemName: icons[index]).font(.system(size: 15)).foregroundStyle(LCTheme.gold)
                        Text(category).font(.system(size: 7, weight: .semibold, design: .serif)).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).frame(height: 78)
                    .background(LCTheme.card)
                    .overlay(Rectangle().stroke(LCTheme.line, lineWidth: 1))
                }
            }
        }
    }
}

struct StoryDetailView: View {
    let story: Story
    @Environment(\.dismiss) private var dismiss
    @State private var reacted = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    RemoteImage(url: story.imageURL).frame(height: 270)
                    Text(story.category.uppercased()).font(.system(size: 8, weight: .bold)).tracking(1.3).foregroundStyle(LCTheme.gold)
                    Text(story.title).font(.system(size: 30, weight: .bold, design: .serif))
                    Text("\(story.author) · \(story.location)").font(.system(size: 9)).foregroundStyle(LCTheme.muted)
                    Text(story.body).font(.system(size: 16, design: .serif)).lineSpacing(5)
                    HStack(spacing: 10) {
                        Button(reacted ? "🍺 Liked" : "🍺 React") { reacted.toggle() }.buttonStyle(LCOutlineButton())
                        Text("💬 \(story.comments)").font(.system(size: 9, weight: .semibold)).foregroundStyle(LCTheme.muted)
                        Spacer()
                    }
                }
                .padding(14)
            }
            .background(LCTheme.black.ignoresSafeArea())
            .foregroundStyle(LCTheme.cream)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
        }
    }
}

struct DiscoverView: View {
    @EnvironmentObject private var model: LastCallModel
    @State private var query = ""

    var filtered: [Story] {
        guard !query.isEmpty else { return model.stories }
        return model.stories.filter { story in
            story.title.localizedCaseInsensitiveContains(query) || story.category.localizedCaseInsensitiveContains(query) || story.location.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Discover").font(.system(size: 31, weight: .bold, design: .serif))
                    TextField("Search stories, cities or categories", text: $query)
                        .textFieldStyle(LCTextFieldStyle())
                    ForEach(filtered) { story in StoryRow(story: story) { } }
                }.padding(14)
            }
            .background(LCTheme.black.ignoresSafeArea())
            .foregroundStyle(LCTheme.cream)
            .navigationBarHidden(true)
        }
    }
}

struct WriteStoryView: View {
    @State private var title = ""
    @State private var bodyText = ""
    @State private var category = "Closing Time"
    @State private var anonymous = true
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Write a story").font(.system(size: 31, weight: .bold, design: .serif))
                    Text("Funny, strange, heartwarming, unforgettable — whatever stayed with you.")
                        .font(.system(size: 13, design: .serif)).foregroundStyle(LCTheme.muted)
                    Group {
                        TextField("Story title (optional)", text: $title).textFieldStyle(LCTextFieldStyle())
                        TextEditor(text: $bodyText).frame(minHeight: 230).scrollContentBackground(.hidden).padding(8).background(LCTheme.card).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(LCTheme.line))
                        Picker("Category", selection: $category) { ForEach(["Closing Time", "After Hours", "Bar Wisdom", "Staff Hours"], id: \.self) { Text($0) } }.pickerStyle(.menu)
                        Toggle("Post anonymously", isOn: $anonymous).tint(LCTheme.green)
                    }
                    Button("SUBMIT STORY →") { submitted = true }.buttonStyle(LCPrimaryButton())
                    if submitted { Text("Thanks — your story is ready for review.").font(.system(size: 10, weight: .semibold)).foregroundStyle(LCTheme.gold) }
                    Text("Stories are reviewed before public publication.").font(.system(size: 9)).foregroundStyle(LCTheme.muted)
                }.padding(14)
            }
            .background(LCTheme.black.ignoresSafeArea()).foregroundStyle(LCTheme.cream).navigationBarHidden(true)
        }
    }
}

struct CommunityPerson: Identifiable { let id = UUID(); let name: String; let place: String }

struct CommunityView: View {
    let people = [CommunityPerson(name: "DanielleR", place: "Galway, Ireland"), CommunityPerson(name: "Liam_Mc", place: "Dublin, Ireland"), CommunityPerson(name: "SarahJ", place: "Cork, Ireland"), CommunityPerson(name: "Tara_92", place: "Limerick, Ireland")]
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 12) { Text("Community").font(.system(size: 31, weight: .bold, design: .serif)); Text("Find people, follow storytellers, keep the craic going.").foregroundStyle(LCTheme.muted); ForEach(people) { person in HStack { Circle().fill(LCTheme.green).frame(width: 38); VStack(alignment: .leading) { Text(person.name).font(.system(size: 12, weight: .semibold)); Text(person.place).font(.system(size: 8)).foregroundStyle(LCTheme.muted) }; Spacer(); Button("Follow") {}.buttonStyle(LCOutlineButton()) } } }.padding(14) }
        .background(LCTheme.black.ignoresSafeArea()).foregroundStyle(LCTheme.cream)
    }
}

struct MessagesView: View {
    let messages = [("DanielleR", "That story was class 🔥"), ("Liam_Mc", "You up for the match tonight?"), ("SarahJ", "Sounds good! Where are you?")]
    var body: some View { NavigationStack { List(messages, id: \.0) { item in HStack { Circle().fill(LCTheme.green).frame(width: 36); VStack(alignment: .leading) { Text(item.0).font(.system(size: 12, weight: .semibold)); Text(item.1).font(.system(size: 9)).foregroundStyle(LCTheme.muted) } } }.scrollContentBackground(.hidden).background(LCTheme.black).foregroundStyle(LCTheme.cream).navigationTitle("Messages") } }
}

struct ProfileView: View {
    var body: some View {
        ScrollView { VStack(spacing: 14) { RemoteImage(url: URL(string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1200&q=80")).frame(height: 180); Circle().fill(LCTheme.green).frame(width: 82).overlay(Text("LC").font(.system(size: 24, weight: .bold))); Text("LAST CALL MEMBER").font(.system(size: 20, weight: .bold, design: .serif)); Text("Good stories. Great company. Always up for a last call. 🍻").font(.system(size: 12, design: .serif)).foregroundStyle(LCTheme.muted).multilineTextAlignment(.center); HStack { Stat(value: "0", label: "Stories"); Stat(value: "0", label: "Followers"); Stat(value: "0", label: "Following") }; Button("EDIT PROFILE") {}.buttonStyle(LCOutlineButton()) }.padding(14) }.background(LCTheme.black.ignoresSafeArea()).foregroundStyle(LCTheme.cream) }
}

struct Stat: View { let value: String; let label: String; var body: some View { VStack { Text(value).font(.system(size: 18, weight: .bold)); Text(label).font(.system(size: 7)).foregroundStyle(LCTheme.muted) }.frame(maxWidth: .infinity) } }

struct RemoteImage: View {
    let url: URL?
    var body: some View { AsyncImage(url: url) { phase in switch phase { case .success(let image): image.resizable().scaledToFill(); default: Rectangle().fill(LCTheme.card).overlay(Image(systemName: "wineglass.fill").foregroundStyle(LCTheme.gold.opacity(0.5))) } }.clipped() }
}

struct LCTheme {
    static let black = Color(red: 0.027, green: 0.027, blue: 0.024)
    static let card = Color(red: 0.055, green: 0.055, blue: 0.047)
    static let cream = Color(red: 0.957, green: 0.929, blue: 0.875)
    static let gold = Color(red: 0.843, green: 0.714, blue: 0.365)
    static let green = Color(red: 0.125, green: 0.357, blue: 0.216)
    static let muted = Color(red: 0.62, green: 0.59, blue: 0.53)
    static let line = Color(red: 0.843, green: 0.714, blue: 0.365).opacity(0.25)
}

struct LCPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 8, weight: .bold)).tracking(1.1).foregroundStyle(LCTheme.cream).padding(.horizontal, 14).frame(minHeight: 38).background(LCTheme.green).clipShape(RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(LCTheme.gold, lineWidth: 1)).opacity(configuration.isPressed ? 0.72 : 1) }
}

struct LCOutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 8, weight: .semibold)).tracking(0.8).foregroundStyle(LCTheme.cream).padding(.horizontal, 11).frame(minHeight: 32).background(LCTheme.card).clipShape(RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(LCTheme.line, lineWidth: 1)).opacity(configuration.isPressed ? 0.7 : 1) }
}

struct LCTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View { configuration.font(.system(size: 12, design: .serif)).foregroundStyle(LCTheme.cream).padding(12).background(LCTheme.card).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(LCTheme.line)) }
}
