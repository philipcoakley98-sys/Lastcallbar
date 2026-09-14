import SwiftUI

struct NativeAuth: View {
  @EnvironmentObject private var model: NativeAppModel
  @Binding var mode: AuthMode
  @Environment(\.dismiss) private var dismiss
  @State private var email = ""
  @State private var password = ""
  @State private var name = ""
  @State private var working = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Text(mode == .signIn ? "Welcome back" : "Become a free member")
            .font(.system(size: 30, weight: .bold, design: .serif))
          if mode == .signUp {
            TextField("Name or display name (optional)", text: $name)
              .textFieldStyle(LCField())
          }
          TextField("Email", text: $email)
            .textFieldStyle(LCField())
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
          SecureField("Password", text: $password)
            .textFieldStyle(LCField())
          Button(
            working ? "PLEASE WAIT…" : (mode == .signIn ? "SIGN IN →" : "CREATE FREE ACCOUNT →")
          ) {
            working = true
            Task {
              if mode == .signIn {
                await model.signIn(email, password)
              } else {
                await model.signUp(email, password, name)
              }
              working = false
            }
          }
          .buttonStyle(PrimaryButton())
          .disabled(working || email.isEmpty || password.count < 6)
          Button(
            mode == .signIn ? "Need an account? Become a free member" : "Already a member? Sign in"
          ) {
            mode = mode == .signIn ? .signUp : .signIn
          }
          .foregroundStyle(Look.gold)
        }
        .padding(13)
      }
      .background(Look.black.ignoresSafeArea())
      .foregroundStyle(Look.cream)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close") { dismiss() }
        }
      }
    }
  }
}
