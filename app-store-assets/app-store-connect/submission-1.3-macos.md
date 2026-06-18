# Hold 1.3 macOS Submission Log

## Target

- App Store Connect app id: `6755408368`
- Bundle id: `com.vishaljain.HoldApp`
- Locale: `en-GB`
- Platform: `MAC_OS`
- macOS appStoreVersion: `acddb634-8390-4817-9eed-87a4823ce80c`
- Marketing version: `1.3`
- macOS build number: `12`

## Local Inputs

- App Store metadata: `macos-listing.md`
- macOS export options: `export-macos-app-store.plist`
- App Store Connect private key: `/Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8`
- Signing keychain: `/Users/vishaljain/.private/appstoreconnect/fence-ios-signing.keychain-db`
- Signing keychain pass file: `/Users/vishaljain/.private/appstoreconnect/fence-ios-signing.keychain.pass`

## Reason

The live iOS 1.2 companion app reads `CurrentTaskPointer.currentTaskId` and `CurrentTaskPointer.currentTaskText` from the user's private CloudKit database. The live macOS 1.2 build `11` writes the pointer timestamp but does not include those field names in its binary, so it can report a successful save while the iPhone receives an empty pointer. This macOS-only release ships the current source that writes the task id and text fields.

## Local Smoke Test

- Launched local macOS build `1.3 (12)` from `/private/tmp/HoldAppLocalRun-1.3-12/Build/Products/Release/Hold.app`.
- Confirmed entitlements use `iCloud.com.vishaljain.HoldApp` with `com.apple.developer.icloud-container-environment=Production`.
- Created child tasks from the local build. macOS logs showed `[SAVE] OK - pointer updated in CloudKit`.
- Verified production `CurrentTaskPointer` through `cktool`; the record contained `currentTaskId`, `currentTaskText`, `parentTaskText`, `rootTaskText`, `siblingPosition`, `siblingCount`, `showEllipsis`, and `timestamp`.

## Version Preparation

```sh
ruby scripts/app_store_connect_update.rb --key-id NA9CQQGYY9 --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 --locale en-GB --platform MAC_OS --prepare-next-version 1.3 --upload-screenshots --apply
```

Result:

- Created macOS version `1.3` as `acddb634-8390-4817-9eed-87a4823ce80c`.
- Patched `en-GB` version metadata on localization `403858dc-7983-4a64-95f6-cbd48455c26c`.
- Existing `APP_DESKTOP` screenshot set `83f2e201-003a-40c6-81e3-50ca593419ab` already had screenshots, so the script left it unchanged.
- Patched App Review detail `7f25a191-39bd-41b3-915b-58f62e0064c0`.

## Archive Command

```sh
/Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh archive-upload MAC_OS 1.3 12
```

Result:

- Archive succeeded at `/private/tmp/HoldAppRelease-1.3-MAC_OS-20260618231228/Hold-macOS.xcarchive`.
- Archive metadata verified `CFBundleShortVersionString=1.3` and `CFBundleVersion=12`.
- The first export attempt failed because App Store Connect reported `PLA Update available` and Xcode could not fetch Mac App Store distribution signing assets. The account agreement was accepted, then export/upload was retried from the successful archive.

## Upload Command

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -exportArchive -archivePath /private/tmp/HoldAppRelease-1.3-MAC_OS-20260618231228/Hold-macOS.xcarchive -exportOptionsPlist app-store-assets/app-store-connect/export-macos-app-store.plist -exportPath /private/tmp/HoldAppRelease-1.3-MAC_OS-20260618231228/macos-upload -allowProvisioningUpdates -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 -authenticationKeyID NA9CQQGYY9 -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403
```

Result:

- Xcode export/upload succeeded.
- App Store Connect reported the uploaded package was processing.

## Submission Command

```sh
HOLD_WAIT_MINUTES=30 /Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh submit MAC_OS 1.3 12 acddb634-8390-4817-9eed-87a4823ce80c
```

Result:

- Found build `74e582af-245d-4c1a-a0ad-2a488b40a7c2`, platform `MAC_OS`, version `1.3 (12)`, processing state `VALID`, uploaded `2026-06-18T15:17:49-07:00`.
- Set export compliance `usesNonExemptEncryption=false`.
- Attached build `74e582af-245d-4c1a-a0ad-2a488b40a7c2` to appStoreVersion `acddb634-8390-4817-9eed-87a4823ce80c`.
- Created reviewSubmission `d95a0b13-56cf-4db4-b61d-1ba61d680739`.
- Submitted reviewSubmission `d95a0b13-56cf-4db4-b61d-1ba61d680739`.
- Final macOS appStoreVersion state: `WAITING_FOR_REVIEW`.
- Attached build: `74e582af-245d-4c1a-a0ad-2a488b40a7c2`, number `12`, processing `VALID`, encryption `false`.
