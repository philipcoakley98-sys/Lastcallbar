import SwiftUI

struct LockedHome: View {
  @EnvironmentObject private var model: NativeAppModel
  private let pubURL = URL(
    string:
      "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto   =   format&fit   =   crop&w   =   1200&q   =   90"
  )
  var body: some View {
    GeometryReader { proxy in
      ZStack {
        NativeImage(url: pubURL).frame(width: proxy.size.width, height: proxy.size.height).overlay(
          LinearGradient(
            colors: [
              .black.opacity(0.34), .black.opacity(0.18), .black.opacity(0.58),
              .black.opacity(0.88),
            ], startPoint: .top, endPoint: .bottom))
        RadialGradient(
          colors: [.clear, .black.opacity(0.52)], center: .center, startRadius: 70,
          endRadius: max(proxy.size.width, proxy.size.height) * 0.78)
        VStack(spacing: 0) {
          HStack(alignment: .top) {
            LastCallAvatar()
            Spacer()
          }.padding(.top, proxy.safeAreaInsets.top + 8).padding(.horizontal, 18)
          Spacer(minLength: 10)
          VStack(spacing: 10) {
            Text("LAST CALL").font(
              .system(size: min(56, proxy.size.width * 0.15), weight: .black, design: .rounded)
            ).tracking(-1.8).foregroundStyle(.white).shadow(
              color: .black.opacity(0.7), radius: 7, y: 4)
            CheersPintsMark().frame(width: 54, height: 32).foregroundStyle(.white)
            Text("Real stories. Real people. Last call.").font(
              .system(size: 15, weight: .semibold, design: .rounded)
            ).foregroundStyle(.white.opacity(0.96)).multilineTextAlignment(.center).shadow(
              color: .black.opacity(0.7), radius: 5, y: 2)
          }.padding(.horizontal, 24)
          Spacer()
          VStack(spacing: 12) {
            Button {
              model.authMode = .signUp
              model.showAuth = true
            } label: {
              Text("Create account").font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Look.black).frame(maxWidth: .infinity).frame(height: 56)
                .background(.white).clipShape(Capsule())
            }
            Button {
              model.authMode = .signIn
              model.showAuth = true
            } label: {
              Text("Sign in").font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 50).background(
                  .black.opacity(0.30)
                ).clipShape(Capsule()).overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
            }
          }.padding(.horizontal, 22).padding(.bottom, proxy.safeAreaInsets.bottom + 22)
        }
      }.ignoresSafeArea().background(Color.black)
    }
  }
}

private struct CheersPintsMark: View {
  var body: some View {
    HStack(spacing: -4) {
      PintShape().rotationEffect(.degrees(-16))
      PintShape().rotationEffect(.degrees(16))
    }
  }
}
private struct PintShape: View {
  var body: some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 4).stroke(.primary, lineWidth: 2.4).frame(
        width: 17, height: 23)
      Capsule().fill(.primary).frame(width: 14, height: 4).offset(y: -1)
    }
  }
}

struct LastCallAvatar: View {
  var body: some View {
    ZStack {
      Circle().fill(Color.black.opacity(0.42)).frame(width: 48, height: 48)
      Circle().fill(Color(red: 0.78, green: 0.55, blue: 0.37)).frame(width: 23, height: 23).offset(
        y: 3)
      Capsule().fill(Color(red: 0.07, green: 0.07, blue: 0.06)).frame(width: 27, height: 9).offset(
        y: -9)
      RoundedRectangle(cornerRadius: 7).fill(.white).frame(width: 29, height: 15).offset(y: 18)
      RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.08, green: 0.08, blue: 0.07)).frame(
        width: 12, height: 15
      ).offset(y: 18)
      Circle().fill(.white).frame(width: 2.2, height: 2.2).offset(x: -4.5, y: 2)
      Circle().fill(.white).frame(width: 2.2, height: 2.2).offset(x: 4.5, y: 2)
    }.frame(width: 50, height: 50).accessibilityHidden(true)
  }
}
