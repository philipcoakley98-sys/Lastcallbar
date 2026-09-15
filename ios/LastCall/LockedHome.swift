import SwiftUI

struct LockedHome: View {
  @EnvironmentObject private var model: NativeAppModel

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Image("LastCallWelcome")
          .resizable()
          .scaledToFill()
          .frame(width: proxy.size.width, height: proxy.size.height)
          .clipped()
          .overlay(
            LinearGradient(
              colors: [
                .clear,
                .clear,
                .black.opacity(0.08),
                .black.opacity(0.62),
                .black.opacity(0.9)
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          )

        VStack(spacing: 12) {
          Spacer()

          VStack(spacing: 10) {
            Button {
              model.authMode = .signUp
              model.showAuth = true
            } label: {
              Text("Create account")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Look.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.white)
                .clipShape(Capsule())
            }

            Button {
              model.authMode = .signIn
              model.showAuth = true
            } label: {
              Text("Sign in")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.black.opacity(0.30))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
            }
          }
          .padding(.horizontal, 22)
          .padding(.bottom, proxy.safeAreaInsets.bottom + 18)
        }
      }
      .ignoresSafeArea()
      .background(Color.black)
    }
  }
}

struct LastCallAvatar: View {
  var body: some View {
    ZStack {
      Circle().fill(Color.black.opacity(0.42)).frame(width: 48, height: 48)
      Circle().fill(Color(red: 0.78, green: 0.55, blue: 0.37)).frame(width: 23, height: 23).offset(y: 3)
      Capsule().fill(Color(red: 0.07, green: 0.07, blue: 0.06)).frame(width: 27, height: 9).offset(y: -9)
      RoundedRectangle(cornerRadius: 7).fill(.white).frame(width: 29, height: 15).offset(y: 18)
      RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.08, green: 0.08, blue: 0.07)).frame(width: 12, height: 15).offset(y: 18)
      Circle().fill(.white).frame(width: 2.2, height: 2.2).offset(x: -4.5, y: 2)
      Circle().fill(.white).frame(width: 2.2, height: 2.2).offset(x: 4.5, y: 2)
    }
    .frame(width: 50, height: 50)
    .accessibilityHidden(true)
  }
}
