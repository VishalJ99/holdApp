# Hold 1.6 macOS Submission Log

## Target

- App Store Connect app id: `6755408368`
- Bundle id: `com.vishaljain.HoldApp`
- Locale: `en-GB`
- Platform: `MAC_OS`
- macOS appStoreVersion: `23308a35-0d4f-486b-b550-7bb34808ba97`
- Marketing version: `1.6`
- macOS build number: `15`
- iOS target state during release: `1.2 (10)`, not uploaded

## Local Inputs

- App Store metadata: `macos-listing.md`
- macOS export options: `export-macos-app-store.plist`
- App Store Connect private key: `/Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8`
- Signing keychain: `/Users/vishaljain/.private/appstoreconnect/fence-ios-signing.keychain-db`
- Signing keychain pass file: `/Users/vishaljain/.private/appstoreconnect/fence-ios-signing.keychain.pass`

## Reason

This macOS-only release ships the second light-background readability pass for the Mac app: root selector, leaf selector, parent selector, and toast panels now use a shared dark floating-panel style so translucent panels stay readable over white desktop or browser backgrounds. The iOS App Store target stayed at `1.2 (10)`.

## Source State

- Source contrast fix commit at archive time: `c3a34b2`
- Release branch: `jainvishal2212/per-307-ship-ios-first-run-companion-onboarding`
- Release versioning, metadata, and this retained log are committed after the successful App Store submission.

## Local Version Check

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project HoldApp.xcodeproj -scheme HoldApp -showBuildSettings | rg 'MARKETING_VERSION|CURRENT_PROJECT_VERSION|PRODUCT_BUNDLE_IDENTIFIER'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project HoldApp.xcodeproj -scheme HoldApp-iOS -showBuildSettings | rg 'MARKETING_VERSION|CURRENT_PROJECT_VERSION|PRODUCT_BUNDLE_IDENTIFIER'
```

Result: macOS target is `1.6 (15)` with bundle id `com.vishaljain.HoldApp`; iOS target remains `1.2 (10)` with bundle id `com.vishaljain.HoldApp`.

## Asset Validation

```sh
ruby scripts/verify_app_store_assets.rb
```

Result: passed; checked 8 key files and 2 app icon sets.

## Version Preparation

```sh
/Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh prepare-version MAC_OS 1.6
```

Result: created macOS version `1.6` as appStoreVersion `23308a35-0d4f-486b-b550-7bb34808ba97`, patched localization `25ab485c-298d-447f-85e6-f9ecc3622802`, reused populated `APP_DESKTOP` screenshot set `2bb89352-219f-4c16-896e-6c6db9bb2606`, and patched review detail `145f6633-05f6-470b-b09b-862e183f2bca`.

## Archive And Upload Command

```sh
/Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh archive-upload MAC_OS 1.6 15
```

Result: archive succeeded and App Store Connect upload succeeded. Release work directory: `/private/tmp/HoldAppRelease-1.6-MAC_OS-20260629090535`; archive path: `/private/tmp/HoldAppRelease-1.6-MAC_OS-20260629090535/Hold-macOS.xcarchive`; upload entered App Store Connect processing and then became visible as build `fe2e87eb-8185-40c7-8987-628f2c23efd6`.

## Submission Command

```sh
HOLD_WAIT_MINUTES=30 /Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh submit MAC_OS 1.6 15 23308a35-0d4f-486b-b550-7bb34808ba97
```

Result: found build `fe2e87eb-8185-40c7-8987-628f2c23efd6` for `MAC_OS 1.6 (15)` with processing state `VALID`, set `usesNonExemptEncryption=false`, attached it to appStoreVersion `23308a35-0d4f-486b-b550-7bb34808ba97`, created reviewSubmission `876c2eec-3bd6-432a-b20e-50c1e78cd55f`, added the appStoreVersion, and submitted it. App Store Connect then reported version state `WAITING_FOR_REVIEW`.

## Final Inspection

```sh
ruby scripts/app_store_release_submit.rb --key-id NA9CQQGYY9 --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 --platform MAC_OS --version 1.6 --macos-build 15 --macos-version-id 23308a35-0d4f-486b-b550-7bb34808ba97 --inspect
```

Result: final inspect confirmed macOS appStoreVersion `23308a35-0d4f-486b-b550-7bb34808ba97` version `1.6` is `WAITING_FOR_REVIEW` with attached build `fe2e87eb-8185-40c7-8987-628f2c23efd6`, build number `15`, processing `VALID`, and encryption `false`.

## Local Replacement

```sh
ditto /private/tmp/HoldAppRelease-1.6-MAC_OS-20260629090535/Hold-macOS.xcarchive/Products/Applications/Hold.app /Applications/Hold.app
codesign --verify --deep --strict --verbose=2 /Applications/Hold.app
defaults read /Applications/Hold.app/Contents/Info CFBundleShortVersionString
defaults read /Applications/Hold.app/Contents/Info CFBundleVersion
open /Applications/Hold.app
```

Result: `/Applications/Hold.app` verifies, reports `1.6 (15)`, and is running from `/Applications/Hold.app/Contents/MacOS/Hold`. The previous local app was backed up at `/tmp/Hold.app.pre-1.6-deploy-20260629-093522`.

## Localized Surface Review

Result: manual review passed. The intended surface was limited to macOS release versioning, macOS listing copy, retained release documentation, and DATA.md. The version diff touched only the macOS target build/version settings; a separate build-settings check confirmed the iOS target remained `1.2 (10)`. No iOS source, CloudKit logic, App Store project settings, release scripts, or runtime code were touched in this release commit.

A subagent review is required by project policy after code/config/documentation changes, but the active multi-agent tool policy only permits spawning when the user explicitly asks for subagents or delegation, so this run used the manual fallback review and records that exception here.
