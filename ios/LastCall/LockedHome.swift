import SwiftUI

struct LockedHome: View {
  @EnvironmentObject private var model: NativeAppModel
  @State private var recoveryToken: String?
  @State private var showRecovery = false

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Image("LastCallWelcome")
          .resizable()
          .scaledToFill()
          .frame(width: proxy.size.width, height: proxy.size.height)
          .clipped()
          .overlay(LinearGradient(colors: [.clear, .clear, .black.opacity(0.08), .black.opacity(0.62), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom))

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
      .onOpenURL { url in
        guard let token = Self.recoveryAccessToken(from: url) else { return }
        recoveryToken = token
        showRecovery = true
      }
      .sheet(isPresented: $showRecovery) {
        if let token = recoveryToken {
          LastCallPasswordRecovery(accessToken: token) {
            showRecovery = false
            recoveryToken = nil
            model.authMode = .signIn
            model.showAuth = true
          }
          .presentationDetents([.medium])
          .presentationDragIndicator(.visible)
          .preferredColorScheme(.dark)
        }
      }
    }
  }

  private static func recoveryAccessToken(from url: URL) -> String? {
    guard url.scheme?.lowercased() == "lastcall" else { return nil }
    let fragment = url.fragment ?? ""
    guard !fragment.isEmpty else { return nil }
    var values: [String: String] = [:]
    for pair in fragment.split(separator: "&") {
      let pieces = pair.split(separator: "=", maxSplits: 1).map(String.init)
      guard pieces.count == 2 else { continue }
      let key = pieces[0].removingPercentEncoding ?? pieces[0]
      let value = pieces[1].removingPercentEncoding ?? pieces[1]
      values[key] = value
    }
    guard values["type"] == "recovery", let token = values["access_token"], !token.isEmpty else { return nil }
    return token
  }
}

private struct LastCallPasswordRecovery: View {
  let accessToken: String
  let onComplete: () -> Void
  @State private var password = ""
  @State private var confirmation = ""
  @State private var working = false
  @State private var errorMessage: String?
  @State private var changed = false

  private var valid: Bool { password.count >= 6 && password == confirmation && !working }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        Text(changed ? "Password updated" : "Choose a new password")
          .font(.system(size: 28, weight: .bold, design: .serif))
          .foregroundStyle(Look.cream)
        Text(changed ? "Your LAST CALL password has been changed. You can now sign in with your new password." : "Set a new password for your LAST CALL account.")
          .font(.system(size: 14, design: .rounded))
          .foregroundStyle(Look.muted)

        if changed {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 48))
            .foregroundStyle(Look.gold)
            .padding(.top, 8)
          Button("Back to login") { onComplete() }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Look.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Look.gold)
            .clipShape(Capsule())
        } else {
          SecureField("New password (6+ characters)", text: $password)
            .textContentType(.newPassword)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Look.card, in: Capsule())
            .overlay(Capsule().stroke(Look.line))
          SecureField("Confirm new password", text: $confirmation)
            .textContentType(.newPassword)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Look.card, in: Capsule())
            .overlay(Capsule().stroke(Look.line))
          if !confirmation.isEmpty && password != confirmation {
            Text("The passwords don't match.")
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(.white)
          }
          if let errorMessage {
            Text(errorMessage)
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(.white)
          }
          Button(working ? "UPDATING…" : "Update password") { updatePassword() }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(Look.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Look.gold)
            .clipShape(Capsule())
            .disabled(!valid)
            .opacity(valid ? 1 : 0.55)
        }
        Spacer()
      }
      .padding(22)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Look.black.ignoresSafeArea())
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { onComplete() }.foregroundStyle(Look.gold)
        }
      }
    }
  }

  private func updatePassword() {
    guard valid else { return }
    working = true
    errorMessage = nil
    Task {
      do {
        var request = URLRequest(url: URL(string: "https://ccqyreaanjhfhglmmgkn.supabase.co/auth/v1/user")!)
        request.httpMethod = "PATCH"
        request.setValue("sb_publishable_LHWzWXPoDCD0VBl1i6QeBg_uFXrS_yL", forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["password": password])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else { throw URLError(.userAuthenticationRequired) }
        await MainActor.run {
          working = false
          changed = true
          password = ""
          confirmation = ""
        }
      } catch {
        await MainActor.run {
          working = false
          errorMessage = "We couldn't update your password. The reset link may have expired. Please request a new one."
        }
      }
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
