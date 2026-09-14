# LAST CALL — iPhone app starter

This folder is the native SwiftUI starting point for LAST CALL.

## Visual direction

The first build follows the approved starter mockup:

- dark Irish-pub editorial look
- cream typography with gold accents and deep green actions
- compact iPhone-first layout
- five-tab navigation: Home, Discover, Write, Messages, Profile
- Story of the Night feature
- story detail, reactions, categories, community and messaging surfaces
- welcoming, anonymous-friendly story submission
- no payments, tipping or subscription language

## Project

Open `LastCall.xcodeproj` in Xcode and run the **LastCall** target on an iPhone simulator or device. Deployment target is iOS 17.

The current source intentionally starts with local sample content so the interface can be built and tested independently. The next implementation step is wiring these screens to the existing LAST CALL Supabase backend for authentication, stories, reactions, follows, conversations, messages and notifications.

The web app remains at https://lastcallbar.co and will continue to use the same Supabase data model.
