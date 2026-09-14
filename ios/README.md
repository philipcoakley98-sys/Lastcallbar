# LAST CALL — native iPhone app

This folder contains the native SwiftUI iPhone app for LAST CALL.

## Visual direction

The build follows the approved starter mockup:

- dark Irish-pub editorial look
- cream typography with gold accents and deep green actions
- compact iPhone-first layout
- six-tab navigation: Home, Stories, Write, People, Messages, Profile
- Story of the Night feature
- story detail, reactions, categories, community and messaging surfaces
- welcoming, anonymous-friendly story submission
- no payments, tipping or subscription language

## Live backend integration

The native app connects to the existing LAST CALL Supabase project using the publishable key only. It includes:

- email/password sign in and free membership creation
- Keychain-backed refresh-session persistence
- published story loading with clearly labelled sample fallback when the database has no published stories yet
- authenticated story submission to the moderation queue (`pending`)
- persistent 🍺 reactions with live reaction counts
- community profile/follow loading and follow/unfollow
- direct message requests with privacy enforcement
- accept/block message requests
- conversation loading, message sending and chat history
- secure message read marking
- notifications with unread state and read marking
- database-level privacy and blocking enforcement
- `lastcall://` auth deep-link scheme prepared for confirmation/password-reset flows

## Project

Open `LastCall.xcodeproj` in Xcode and run the **LastCall** target on an iPhone simulator or device. Deployment target is iOS 17.

The repository work is being completed independently of Xcode. Final simulator/device compilation, signing and TestFlight upload must be performed in Xcode on macOS.

For external TestFlight distribution, the first build must go through TestFlight App Review; after approval, testers can be invited by email or public link.

The web app remains at https://lastcallbar.co and continues to use the same Supabase data model.
