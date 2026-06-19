# Hold 1.4 macOS Submission Log

## Target

- App Store Connect app id: `6755408368`
- Bundle id: `com.vishaljain.HoldApp`
- Locale: `en-GB`
- Platform: `MAC_OS`
- macOS appStoreVersion: `531e355f-a1a1-4427-833f-70a9b6cdb772`
- Marketing version: `1.4`
- macOS build number: `13`
- iOS target state during release: `1.2 (10)`, not uploaded

## Local Inputs

- App Store metadata: `macos-listing.md`
- macOS export options: `export-macos-app-store.plist`
- App Store Connect private key: `/Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8`
- Signing keychain: `/Users/vishaljain/.private/appstoreconnect/fence-ios-signing.keychain-db`
- Signing keychain pass file: `/Users/vishaljain/.private/appstoreconnect/fence-ios-signing.keychain.pass`

## Reason

This macOS-only release ships the current Mac target after the leaf selector usability work and the serialized CloudKit `CurrentTaskPointer` save path. The CloudKit manager source is shared with iOS, but this submission archived and uploaded only the macOS `HoldApp` scheme; the iOS App Store target stayed at `1.2 (10)`.

## Local Version Check

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project HoldApp.xcodeproj -scheme HoldApp -showBuildSettings | rg 'MARKETING_VERSION|CURRENT_PROJECT_VERSION|PRODUCT_BUNDLE_IDENTIFIER'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project HoldApp.xcodeproj -scheme HoldApp-iOS -showBuildSettings | rg 'MARKETING_VERSION|CURRENT_PROJECT_VERSION|PRODUCT_BUNDLE_IDENTIFIER'
```

Result:

- macOS target: `MARKETING_VERSION = 1.4`, `CURRENT_PROJECT_VERSION = 13`, `PRODUCT_BUNDLE_IDENTIFIER = com.vishaljain.HoldApp`
- iOS target: `MARKETING_VERSION = 1.2`, `CURRENT_PROJECT_VERSION = 10`, `PRODUCT_BUNDLE_IDENTIFIER = com.vishaljain.HoldApp`

## Asset Validation

```sh
ruby scripts/verify_app_store_assets.rb
```

Result:

- App Store asset validation passed.
- Checked 8 key files and 2 app icon sets.

## Version Preparation

```sh
ruby scripts/app_store_connect_update.rb --key-id NA9CQQGYY9 --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 --locale en-GB --platform MAC_OS --prepare-next-version 1.4 --upload-screenshots --apply
```

Result:

- Created macOS version `1.4` as `531e355f-a1a1-4427-833f-70a9b6cdb772`.
- Patched `en-GB` version metadata on localization `67feaae5-9312-48d0-9b86-b9f070c9cc36`.
- Existing `APP_DESKTOP` screenshot set `20f946d6-2e6f-4a2e-8bc2-150192b1a382` already had screenshots, so the script left it unchanged.
- Patched App Review detail `787ec00f-0aa3-45ae-ba91-a1e877475254`.

## Archive And Upload Command

```sh
/Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh archive-upload MAC_OS 1.4 13
```

Result:

- Archive succeeded at `/private/tmp/HoldAppRelease-1.4-MAC_OS-20260619142047/Hold-macOS.xcarchive`.
- Archive metadata verified `CFBundleShortVersionString=1.4` and `CFBundleVersion=13`.
- Xcode export/upload succeeded.
- App Store Connect reported the uploaded package was processing.
- Release directory: `/private/tmp/HoldAppRelease-1.4-MAC_OS-20260619142047`

## Submission Command

```sh
HOLD_WAIT_MINUTES=30 /Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh submit MAC_OS 1.4 13 531e355f-a1a1-4427-833f-70a9b6cdb772
```

Result:

- Found build `385a720f-fc42-4f11-a561-92c4eb6196d7`, platform `MAC_OS`, version `1.4 (13)`, processing state `VALID`, uploaded `2026-06-19T06:22:53-07:00`.
- Set export compliance `usesNonExemptEncryption=false`.
- Attached build `385a720f-fc42-4f11-a561-92c4eb6196d7` to appStoreVersion `531e355f-a1a1-4427-833f-70a9b6cdb772`.
- Created reviewSubmission `83ea4f2a-a3e4-49eb-8b08-0b1e952b60bb`.
- Submitted reviewSubmission `83ea4f2a-a3e4-49eb-8b08-0b1e952b60bb`.
- Final macOS appStoreVersion state: `WAITING_FOR_REVIEW`.
- Attached build: `385a720f-fc42-4f11-a561-92c4eb6196d7`, number `13`, processing `VALID`, encryption `false`.

## Final Inspection

```sh
ruby scripts/app_store_release_submit.rb --key-id NA9CQQGYY9 --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 --platform MAC_OS --version 1.4 --macos-build 13 --macos-version-id 531e355f-a1a1-4427-833f-70a9b6cdb772 --inspect
```

Result:

- macOS target `1.4 (13)`.
- macOS appStoreVersion `531e355f-a1a1-4427-833f-70a9b6cdb772` state `WAITING_FOR_REVIEW`.
- Attached build `385a720f-fc42-4f11-a561-92c4eb6196d7`, number `13`, processing `VALID`, encryption `false`.
