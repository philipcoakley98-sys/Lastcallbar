# LAST CALL — native iPhone app

This folder contains the native SwiftUI iPhone app for LAST CALL.

## Visual direction

The build follows the approved starter mockup:

- dark Irish-pub editorial look
- cream typography with gold accents and deep green actions
- compact iPhone-first layout
- five-tab navigation: Home, Discover, Write, Messages, Profile
- Story of the Night feature
- story detail, reactions, categories, community and messaging surfaces
- welcoming, anonymous-friendly story submission
- no payments, tipping or subscription language

## Live backend integration

The native app now connects to the existing LAST CALL Supabase project using the publishable key only. It includes:

- email/password sign in and free membership creation
- Keychain-backed refresh-session persistence
- published story loading with sample fallback when the database has no published stories yet
- authenticated story submission to the moderation queue (`pending`)
- persistent 🍺 reactions
- community profile/follow loading and follow/unfollow
- conversation loading, message requests, message sending and chat history
- notifications with unread state and read marking
- message privacy and blocking enforcement in the database

## Project

Open `LastCall.xcodeproj` in Xcode and run the **LastCall** target on an iPhone simulator or device. Deployment target is iOS 17.

The Linux environment used for repository work cannot run Xcode/iOS SDK builds, so final simulator/device compilation and TestFlight signing still need to be performed in Xcode on macOS.

The web app remains at https://lastcallbar.co and continues to use the same Supabase data model.
