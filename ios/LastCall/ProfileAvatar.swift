import PhotosUI
import SwiftUI
import UIKit

// Profile photos are intentionally handled in one reusable control so the
// same avatar can be updated from Profile without introducing another screen.
struct LastCallProfilePhotoPicker: View {
  @EnvironmentObject private var model: NativeAppModel
  @State private var item: PhotosPickerItem?
  @State private var uploading = false
  @State private var showPicker = false

  var body: some View {
    Button { showPicker = true } label: {
      ProfileAvatar(profile: model.profile, size: 92)
        .overlay(Circle().stroke(Look.gold, lineWidth: 2))
        .overlay(alignment: .bottomTrailing) {
          Image(systemName: uploading ? "arrow.triangle.2.circlepath" : "camera.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Look.black)
            .frame(width: 30, height: 30)
            .background(Look.gold, in: Circle())
            .overlay(Circle().stroke(Look.black, lineWidth: 3))
        }
    }
    .buttonStyle(.plain)
    .photosPicker(isPresented: $showPicker, selection: $item, matching: .images)
    .onChange(of: item) { _, newItem in
      guard let newItem else { return }
      Task { await upload(newItem) }
    }
    .disabled(uploading)
  }

  private func upload(_ item: PhotosPickerItem) async {
    guard let token = model.token, let userID = model.user?.id else { return }
    await MainActor.run { uploading = true }
    do {
      guard let data = try await item.loadTransferable(type: Data.self),
            let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.84) else {
        throw LastCallAPIError.server("That photo could not be prepared.")
      }
      _ = try await LastCallAPI.shared.uploadProfileAvatar(jpeg: jpeg, userID: userID, accessToken: token)
      await model.refreshAccount()
      await MainActor.run {
        uploading = false
        self.item = nil
      }
    } catch {
      await MainActor.run {
        uploading = false
        model.error = "Your profile photo could not be saved. Please try another photo."
      }
    }
  }
}
