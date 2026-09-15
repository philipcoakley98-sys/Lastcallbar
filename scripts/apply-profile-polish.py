from pathlib import Path

p = Path('ios/LastCall/NativeApp.swift')
s = p.read_text()

# Make the helper safe to run against either the pre-polish or already-polished tree.
if 'LastCallProfileScreen' in s:
    raise SystemExit(0)

needle = 'case .profile: NativeProfile()'
if needle not in s:
    raise SystemExit('profile route missing')

s = s.replace(needle, 'case .profile: LastCallProfileScreen()', 1)
s += r'''

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
'''
p.write_text(s)
