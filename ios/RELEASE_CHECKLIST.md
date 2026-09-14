# LAST CALL iPhone release checklist

## Complete in repository

- [x] Native SwiftUI application target
- [x] Five-tab iPhone navigation: Home, Stories, Write, Messages, Profile
- [x] Community / People presented as a sheet
- [x] Supabase authentication client
- [x] Keychain-backed session persistence
- [x] Story feed and story detail
- [x] 🍺 reactions and reaction counts
- [x] Story submission to the moderation queue
- [x] Community follows and messaging
- [x] Message-request accept/block flow
- [x] Notifications and read state
- [x] Database privacy/blocking enforcement
- [x] Privacy manifest
- [x] iOS 17 deployment target
- [x] Version 1.0.0 / build 1
- [x] macOS GitHub Actions simulator build workflow

## Final device/TestFlight stage

- [ ] Cloud simulator build passes on the current `main` commit
- [ ] Run the app on an iPhone simulator and visually QA the approved starter layout
- [ ] Test sign-in, sign-up, email confirmation and session restore
- [ ] Test story submission, reaction, community, messaging and notifications end-to-end
- [ ] Configure the App Store Connect app record
- [ ] Configure Apple signing/provisioning for `com.lastcall.app`
- [ ] Produce the signed TestFlight build
- [ ] Complete TestFlight review/distribution

The signed/TestFlight steps require an active Apple Developer Program membership. No paid cloud Mac service is required for the repository build workflow.
