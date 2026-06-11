# Hold System Architecture

Last updated: June 11, 2026

## Project Map

- `HoldApp/` contains the macOS app target. It owns fast task capture, local task storage, hotkeys, menu/window behavior, and CloudKit current-task sync. `HoldApp/CloudKitManager.swift` owns the shared CloudKit container access, current pointer reads/writes, Mac presence heartbeat, and silent notification subscription setup.
- `HoldApp-iOS/` contains the iOS app target. It displays the current task, listens for CloudKit-driven refreshes, presents a minimalist Mac companion onboarding flow when the Mac heartbeat is absent, and offers a single-field standalone hold entry only when no fresh Mac presence heartbeat is available. `HoldApp-iOS/HoldApp_iOSApp.swift` handles launch and silent remote-notification registration while deferring CloudKit reads to the SwiftUI view lifecycle.
- `HoldApp.xcodeproj/` contains the Xcode project, schemes, target settings, bundle identifiers, signing settings, and version/build numbers.
- `HoldApp/Assets.xcassets/AppIcon.appiconset/` contains the generated macOS app icon sizes. `HoldApp/Assets.xcassets/hold_icon.imageset/` contains the 18-point 1x/2x/3x macOS menu-bar template mark used as the icon-only status item.
- `HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/` contains the generated iOS and App Store marketing app icon sizes.
- `design/Vision.md` contains product positioning and App Store copy source material.
- `.claude/SYSTEM_ARCHITECTURE.md` contains the older detailed architecture notes for local-first task storage, hotkeys, and selectors.
- `PRIVACY.md` and `SUPPORT.md` are public App Store listing documents.
- `release_guide.md` is the release playbook for local App Store page preview, metadata validation, Xcode archive/upload, App Store Connect submission, monitoring, and release closeout checks.
- `DATA.md` is the lightweight manifest for retained non-source assets and App Store metadata.
- `app-store-assets/` contains App Store metadata, generated screenshots, and reproduction notes.
- `app-store-assets/branding/` contains the synced Hold brand package, extracted logo assets, brand tokens, and `generate_icons.sh` for regenerating icon asset catalogs from `source/hold_logo_package.zip`.
- `app-store-assets/app-store-connect/` contains platform-specific iOS/macOS paste targets, live-update handoff notes, a retained `preflight-1.1.json` dry-run report, and reproduction notes for App Store Connect update workflows.
- `app-store-assets/app-store-connect/landing-preview.html` is the generated local product-page preview for comparing iOS and macOS listing copy and screenshots before App Store Connect submission.
- `app-store-assets/app-store-connect/submission-1.1.md` records the reproducible archive, upload, and App Review submission commands for the staged `1.1` release.
- `app-store-assets/app-store-connect/export-ios-app-store.plist` and `app-store-assets/app-store-connect/export-macos-app-store.plist` are the Xcode export option files for uploading `1.1` iOS and macOS archives to App Store Connect with automatic signing.
- `scripts/app_store_connect_update.rb` contains the App Store Connect API updater for dry-running and applying version metadata/review-note changes from the platform handoff markdown, including guarded editable-version screenshot replacement.
- `scripts/generate_app_store_preview.rb` contains the static App Store product-page preview generator. It parses the iOS/macOS listing markdown, resolves referenced screenshots and icons, embeds copy/field-length data, and writes `app-store-assets/app-store-connect/landing-preview.html`.
- `scripts/app_store_release_submit.rb` contains the App Store Connect release submission helper for inspecting build attachment/submission state, waiting for uploaded builds to become `VALID`, setting `usesNonExemptEncryption=false`, attaching builds to `appStoreVersion` records, and submitting via the current `reviewSubmissions` plus `reviewSubmissionItems` flow.
- `scripts/set_app_release_version.rb` contains the guarded local release-version helper for dry-running and applying iOS/macOS app target `MARKETING_VERSION` changes in the Xcode project without touching test targets.
- `scripts/verify_app_store_assets.rb` validates generated App Store screenshots, marketing icons, the macOS menu-bar template image, and all app icon asset-catalog slots referenced by `Contents.json`.

## Core Data Flow

1. The macOS app stores full task records locally in `~/Library/Application Support/HoldApp/tasks.json` through `HoldApp/LocalTaskStore.swift`.
2. The macOS app writes only the current display pointer to the user's private CloudKit database through `HoldApp/CloudKitManager.swift`.
3. The macOS app writes a `MacPresence` record named `MAC_PRESENCE` on launch and every 60 seconds while running. The iOS app treats the Mac as present when `lastSeenAt` is less than five minutes old.
4. The shared CloudKit manager uses the explicit `iCloud.com.vishaljain.HoldApp` container so the iOS companion and macOS app read/write the same private CloudKit pointer.
5. `HoldApp/AppDelegate.swift` creates the menu-bar status item before CloudKit startup. Debug launches with `HOLD_MENU_BAR_SMOKE_TEST=1` return immediately after menu-bar setup so unsigned local builds can verify the compiled status-item icon without touching CloudKit or Keychain.
6. The iOS app reads the current pointer through `HoldApp/CloudKitManager.swift` shared logic and renders a single current task in `HoldApp-iOS/ContentView.swift`.
7. If the current pointer is empty and `MacPresence` is missing or stale, `HoldApp-iOS/ContentView.swift` first shows the first-run Mac companion onboarding carousel. The onboarding uses a black background, horizontally arranged step dots, and explains that the Mac app unlocks child tasks, sibling tasks, multiple roots, and keyboard-shortcut capture.
8. After onboarding is completed or skipped, the same stale/no-Mac path shows one standalone input for "what are you currently holding?" and writes that text back to `CURRENT_TASK_POINTER` with `sourcePlatform = iOS`.
9. `HoldApp-iOS/HoldApp_iOSApp.swift` avoids CloudKit work in `didFinishLaunching`; CloudKit fetch/subscription setup starts after SwiftUI renders to avoid App Review launch-time CloudKit traps.
10. CloudKit silent notifications wake the iOS app to refresh the display after the current task changes.

## App Store Deployment Assets

- App Store metadata is tracked in `app-store-assets/metadata.md`.
- Platform-specific App Store Connect handoff fields are tracked in `app-store-assets/app-store-connect/ios-listing.md` and `app-store-assets/app-store-connect/macos-listing.md`.
- Local storefront copy/design iteration uses `ruby scripts/generate_app_store_preview.rb`, which regenerates `app-store-assets/app-store-connect/landing-preview.html` from the listing markdown and current screenshot/icon assets.
- API-based App Store Connect updates are documented in `app-store-assets/app-store-connect/api-update.md`; `scripts/app_store_connect_update.rb` validates local handoff markdown with `--local-check`, dry-runs live `en-GB` record selection by default, blocks broad `--apply` against non-editable App Store versions, offers `--promotional-text-only` for the live `READY_FOR_SALE` records, and supports a guarded `--prepare-next-version` flow for creating/updating editable versions with full staged metadata plus optional `--upload-screenshots` uploads and `--replace-screenshots` replacement of inherited screenshots on editable versions.
- Preflight reports from `scripts/app_store_connect_update.rb --write-preflight` include live App Store records, planned actions, screenshot checksums, and local Xcode `MARKETING_VERSION`/build-number state so release-version mismatches are visible before creating App Store records.
- Local release version alignment is handled by `ruby scripts/set_app_release_version.rb --version <version> --apply`; for the staged `1.1` submission it updates only the iOS and macOS app target `MARKETING_VERSION` values while preserving current build numbers unless explicit build-number flags are passed.
- App Store binary release submission is handled by `ruby scripts/app_store_release_submit.rb --wait-minutes <n> --apply` after archives have uploaded. The helper uses the non-deprecated review submission API: build attachment on `appStoreVersions`, build export compliance on `builds`, `reviewSubmissions` as the review container, `reviewSubmissionItems` for the app version, and `submitted=true` on the review submission.
- App Store archives must use `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild` or `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` so uploads are built with the currently required iOS/macOS SDK. The selected developer directory may point at an older Xcode in `~/Downloads`.
- Hold brand tokens and source package files are tracked in `app-store-assets/branding/`.
- App icons are regenerated with `bash app-store-assets/branding/generate_icons.sh`, using `hold_inverse_avatar.png` for opaque iOS/macOS AppIcon slots and `hold_icon_white.png` for the macOS menu-bar template image. The generator converts the dark inner Hold cutout to transparent alpha so AppKit template rendering preserves the mark in the menu bar.
- Public support and privacy URLs use the GitHub-hosted `SUPPORT.md` and `PRIVACY.md` files.
- Screenshots are generated marketing screenshots representing the real one-task display and Mac capture workflow, with reproduction notes in `app-store-assets/reproduction.txt`.
- App Store image assets are validated with `ruby scripts/verify_app_store_assets.rb`, which checks required dimensions and alpha-channel expectations for screenshots, marketing icons, and app icon slots.
