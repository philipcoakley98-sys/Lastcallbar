import SwiftUI

struct NativeAuth: View {
  @EnvironmentObject private var model: NativeAppModel
  @Binding var mode: AuthMode
  @Environment(\.dismiss) private var dismiss
  @State private var email = ""
  @State private var password = ""
  @State private var name = ""
  @State private var working = false
  @State private var localError: String?

  private let pubURL = URL(
    string: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1400&q=90"
  )!

  private var trimmedEmail: String {
    email.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSubmit: Bool {
    !working && !trimmedEmail.isEmpty && password.count >= 6
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        NativeImage(url: pubURL)
          .frame(width: proxy.size.width, height: proxy.size.height)
          .overlay(
            LinearGradient(
              colors: [.black.opacity(0.18), .black.opacity(0.28), .black.opacity(0.72), .black.opacity(0.96)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .overlay(Color.black.opacity(0.12))

        ScrollView(showsIndicators: false) {
          VStack(spacing: 0) {
            HStack {
              Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                  .font(.system(size: 18, weight: .semibold))
                  .foregroundStyle(.white)
                  .frame(width: 44, height: 44)
                  .background(.black.opacity(0.25), in: Circle())
              }
              Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, proxy.safeAreaInsets.top + 4)

            VStack(spacing: 8) {
              Text("LAST CALL")
                .font(.system(size: min(57, proxy.size.width * 0.15), weight: .black, design: .rounded))
                .tracking(-1.8)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.75), radius: 8, y: 4)
              HStack(spacing: -4) {
                PintIcon(rotation: -14)
                PintIcon(rotation: 14)
              }
              .frame(height: 34)
              Text("That's the craic.")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(Look.gold)
              Rectangle()
                .fill(Look.gold)
                .frame(width: 92, height: 2)
              Text("Stories From Behind the Bar")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
              Text("IRISH ROOTS  •  WORLDWIDE STORIES")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(2.1)
                .foregroundStyle(Look.gold)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)

            Spacer(minLength: 64)

            VStack(spacing: 12) {
              if mode == .signUp {
                TextField("Name or display name (optional)", text: $name)
                  .modifier(AuthField(icon: "person", placeholder: "Name or display name (optional)", text: $name))
              }

              TextField("Email address", text: $email)
                .modifier(AuthField(icon: "envelope", placeholder: "Email address", text: $email))
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)

              AuthSecureField(icon: "lock", placeholder: "Password (6+ characters)", text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)

              if let localError {
                Text(localError)
                  .font(.system(size: 12, weight: .semibold, design: .rounded))
                  .foregroundStyle(.white)
                  .multilineTextAlignment(.center)
                  .padding(.horizontal, 10)
              }

              Button {
                submit()
              } label: {
                Text(working ? "PLEASE WAIT…" : (mode == .signIn ? "Log in" : "Create account"))
                  .font(.system(size: 17, weight: .bold, design: .rounded))
                  .foregroundStyle(Look.black)
                  .frame(maxWidth: .infinity)
                  .frame(height: 56)
                  .background(Look.gold)
                  .clipShape(Capsule())
              }
              .disabled(!canSubmit)
              .opacity(canSubmit ? 1 : 0.55)

              if mode == .signUp {
                Text("Your name is optional. You only need an email and a password to get started.")
                  .font(.system(size: 11, design: .rounded))
                  .foregroundStyle(.white.opacity(0.72))
                  .multilineTextAlignment(.center)
                  .padding(.horizontal, 12)
              }

              HStack(spacing: 5) {
                Text(mode == .signIn ? "Don't have an account?" : "Already have an account?")
                  .foregroundStyle(.white.opacity(0.92))
                Button(mode == .signIn ? "Sign up →" : "Log in →") {
                  localError = nil
                  mode = mode == .signIn ? .signUp : .signIn
                }
                .foregroundStyle(Look.gold)
                .fontWeight(.semibold)
              }
              .font(.system(size: 14, design: .rounded))

              if mode == .signIn {
                Button("Forgot password?") {
                  localError = "Password reset will be available once email recovery is connected."
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Look.gold)
                .padding(.top, 8)
              }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, proxy.safeAreaInsets.bottom + 28)
          }
          .frame(minHeight: proxy.size.height)
        }
      }
      .ignoresSafeArea()
      .background(Color.black)
      .preferredColorScheme(.dark)
      .onChange(of: mode) { _, _ in localError = nil }
    }
  }

  private func submit() {
    localError = nil
    let normalized = trimmedEmail
    guard !normalized.isEmpty else {
      localError = "Enter your email address."
      return
    }
    guard password.count >= 6 else {
      localError = "Your password needs at least 6 characters."
      return
    }

    working = true
    Task {
      if mode == .signIn {
        await model.signIn(normalized, password)
      } else {
        await model.signUp(normalized, password, name.trimmingCharacters(in: .whitespacesAndNewlines))
      }
      working = false
    }
  }
}

private struct AuthField: ViewModifier {
  let icon: String
  let placeholder: String
  @Binding var text: String

  func body(content: Content) -> some View {
    HStack(spacing: 13) {
      Image(systemName: icon)
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(.white)
      content
        .foregroundStyle(.white)
        .font(.system(size: 16, design: .rounded))
        .tint(.white)
        .placeholder(when: text.isEmpty) {
          Text(placeholder).foregroundStyle(.white.opacity(0.55))
        }
    }
    .padding(.horizontal, 17)
    .frame(height: 56)
    .background(.black.opacity(0.58), in: Capsule())
    .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
  }
}

private extension View {
  @ViewBuilder
  func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder content: () -> Content) -> some View {
    ZStack(alignment: alignment) {
      content().opacity(shouldShow ? 1 : 0)
      self
    }
  }
}

private struct AuthSecureField: View {
  let icon: String
  let placeholder: String
  @Binding var text: String
  @State private var visible = false

  var body: some View {
    HStack(spacing: 13) {
      Image(systemName: icon)
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(.white)
      Group {
        if visible {
          TextField(placeholder, text: $text)
        } else {
          SecureField(placeholder, text: $text)
        }
      }
      .foregroundStyle(.white)
      .font(.system(size: 16, design: .rounded))
      .tint(.white)
      Button { visible.toggle() } label: {
        Image(systemName: visible ? "eye.slash" : "eye")
          .foregroundStyle(.white)
      }
    }
    .padding(.horizontal, 17)
    .frame(height: 56)
    .background(.black.opacity(0.58), in: Capsule())
    .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
  }
}

private struct PintIcon: View {
  let rotation: Double
  var body: some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 4)
        .stroke(.white, lineWidth: 2.3)
        .frame(width: 17, height: 24)
      Capsule()
        .fill(.white)
        .frame(width: 14, height: 4)
        .offset(y: -1)
    }
    .rotationEffect(.degrees(rotation))
  }
}
