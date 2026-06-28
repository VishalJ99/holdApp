# Hold 1.5 macOS Submission Log

## Target

- App Store Connect app id: `6755408368`
- Bundle id: `com.vishaljain.HoldApp`
- Locale: `en-GB`
- Platform: `MAC_OS`
- macOS appStoreVersion: `50889004-2853-4efd-85a1-ddf20e4ca242`
- Marketing version: `1.5`
- macOS build number: `14`
- iOS target state during release: `1.2 (10)`, not uploaded

## Local Inputs

- App Store metadata: `macos-listing.md`
- macOS export options: `export-macos-app-store.plist`
- App Store Connect private key: `/Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8`
- Signing keychain: `/Users/vishaljain/.private/appstoreconnect/fence-ios-signing.keychain-db`
- Signing keychain pass file: `/Users/vishaljain/.private/appstoreconnect/fence-ios-signing.keychain.pass`

## Reason

This macOS-only release ships the light-background readability fixes for the Mac app: adaptive Spotlight input text and placeholder colors, plus a stable dark frosted welcome guide panel so onboarding remains readable over white backgrounds. The iOS App Store target stayed at `1.2 (10)`.

## Source State

- Source commit at archive time: `pending`
- Release branch: `jainvishal2212/per-307-ship-ios-first-run-companion-onboarding`

## Local Version Check

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project HoldApp.xcodeproj -scheme HoldApp -showBuildSettings | rg 'MARKETING_VERSION|CURRENT_PROJECT_VERSION|PRODUCT_BUNDLE_IDENTIFIER'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project HoldApp.xcodeproj -scheme HoldApp-iOS -showBuildSettings | rg 'MARKETING_VERSION|CURRENT_PROJECT_VERSION|PRODUCT_BUNDLE_IDENTIFIER'
```

Result: macOS target is `1.5 (14)` with bundle id `com.vishaljain.HoldApp`; iOS target remains `1.2 (10)` with bundle id `com.vishaljain.HoldApp`.

## Asset Validation

```sh
ruby scripts/verify_app_store_assets.rb
```

Result: passed; checked 8 key files and 2 app icon sets.

## Version Preparation

```sh
ruby scripts/app_store_connect_update.rb --key-id NA9CQQGYY9 --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 --locale en-GB --platform MAC_OS --prepare-next-version 1.5 --upload-screenshots --apply
```

Result: created macOS version `1.5` as appStoreVersion `50889004-2853-4efd-85a1-ddf20e4ca242`, patched localization `2148dea4-ad1d-4680-849e-2653ae47cc3d`, reused populated `APP_DESKTOP` screenshot set `a1918fa1-50a8-4d95-b6af-1f2f4671ef37`, and patched review detail `150fc022-2354-4a2f-9dea-c6222a147d6b`.

## Archive And Upload Command

```sh
/Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh archive-upload MAC_OS 1.5 14
```

Result: pending.

## Submission Command

```sh
HOLD_WAIT_MINUTES=30 /Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh submit MAC_OS 1.5 14 50889004-2853-4efd-85a1-ddf20e4ca242
```

Result: pending.

## Final Inspection

```sh
ruby scripts/app_store_release_submit.rb --key-id NA9CQQGYY9 --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 --platform MAC_OS --version 1.5 --macos-build 14 --macos-version-id 50889004-2853-4efd-85a1-ddf20e4ca242 --inspect
```

Result: pending.
