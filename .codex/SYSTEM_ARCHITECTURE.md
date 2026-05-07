# Hold System Architecture

Last updated: May 7, 2026

## Project Map

- `HoldApp/` contains the macOS app target. It owns fast task capture, local task storage, hotkeys, menu/window behavior, and CloudKit current-task sync.
- `HoldApp-iOS/` contains the iOS app target. It displays the current task and listens for CloudKit-driven refreshes.
- `HoldApp.xcodeproj/` contains the Xcode project, schemes, target settings, bundle identifiers, signing settings, and version/build numbers.
- `design/Vision.md` contains product positioning and App Store copy source material.
- `.claude/SYSTEM_ARCHITECTURE.md` contains the older detailed architecture notes for local-first task storage, hotkeys, and selectors.
- `PRIVACY.md` and `SUPPORT.md` are public App Store listing documents.
- `app-store-assets/` contains App Store metadata and screenshot reproduction notes.

## Core Data Flow

1. The macOS app stores full task records locally in `~/Library/Application Support/HoldApp/tasks.json` through `HoldApp/LocalTaskStore.swift`.
2. The macOS app writes only the current display pointer to the user's private CloudKit database through `HoldApp/CloudKitManager.swift`.
3. The iOS app reads the current pointer through `HoldApp/CloudKitManager.swift` shared logic and renders a single current task in `HoldApp-iOS/ContentView.swift`.
4. CloudKit silent notifications wake the iOS app to refresh the display after the current task changes.

## App Store Deployment Assets

- App Store metadata is tracked in `app-store-assets/metadata.md`.
- Public support and privacy URLs use the GitHub-hosted `SUPPORT.md` and `PRIVACY.md` files.
- Screenshots are generated marketing screenshots representing the real one-task display and Mac capture workflow, with reproduction notes in `app-store-assets/reproduction.txt`.
