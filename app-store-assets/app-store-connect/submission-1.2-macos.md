# Hold 1.2 macOS Submission Log

## Target

- App Store Connect app id: `6755408368`
- Bundle id: `com.vishaljain.HoldApp`
- Locale: `en-GB`
- Platform: `MAC_OS`
- macOS appStoreVersion: `a8105b04-2b0d-4b5a-ad67-067af99271a5`
- Marketing version: `1.2`
- macOS build number: `11`

## Local Inputs

- App Store metadata: `macos-listing.md`
- macOS export options: `export-macos-app-store.plist`
- App Store Connect private key: `/Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8`
- Signing keychain: `/Users/vishaljain/.private/appstoreconnect/fence-ios-signing.keychain-db`
- Signing keychain pass file: `/Users/vishaljain/.private/appstoreconnect/fence-ios-signing.keychain.pass`

## Version Preparation

```sh
ruby scripts/app_store_connect_update.rb --key-id NA9CQQGYY9 --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 --locale en-GB --platform MAC_OS --prepare-next-version 1.2 --upload-screenshots --apply
```

Result:

- Created macOS version `1.2` as `a8105b04-2b0d-4b5a-ad67-067af99271a5`.
- Patched `en-GB` version metadata on localization `9fb1d5d5-2ae0-416e-8512-38b0c901a289`.
- Existing `APP_DESKTOP` screenshot set `0a95c228-1ce0-4d29-8368-cc5d1858e220` already had screenshots, so the script left it unchanged.
- Patched App Review detail `ed77a889-b726-40e9-bc92-d520fd5b1c4b`.

## Archive Command

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project HoldApp.xcodeproj -scheme HoldApp -configuration Release -destination 'generic/platform=macOS' -archivePath /private/tmp/HoldAppRelease-1.2-macOS-20260611130407/Hold-macOS.xcarchive -derivedDataPath /private/tmp/HoldAppRelease-1.2-macOS-20260611130407/DerivedData -allowProvisioningUpdates -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 -authenticationKeyID NA9CQQGYY9 -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403 archive
```

Result:

- Archive succeeded at `/private/tmp/HoldAppRelease-1.2-macOS-20260611130407/Hold-macOS.xcarchive`.
- Archive metadata verified `CFBundleShortVersionString=1.2` and `CFBundleVersion=11`.
- The first archive attempt was interrupted because `codesign` prompted for the `fence-ios-signing` keychain. The successful rerun unlocked `/Users/vishaljain/.private/appstoreconnect/fence-ios-signing.keychain-db` by reading the local pass file directly without printing the password.

## Upload Command

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -exportArchive -archivePath /private/tmp/HoldAppRelease-1.2-macOS-20260611130407/Hold-macOS.xcarchive -exportOptionsPlist app-store-assets/app-store-connect/export-macos-app-store.plist -exportPath /private/tmp/HoldAppRelease-1.2-macOS-20260611130407/macos-upload -allowProvisioningUpdates -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 -authenticationKeyID NA9CQQGYY9 -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403
```

Result:

- Xcode export/upload succeeded.
- App Store Connect reported the uploaded package was processing.

## Submission Command

```sh
HOLD_WAIT_MINUTES=30 /Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh submit MAC_OS 1.2 11 a8105b04-2b0d-4b5a-ad67-067af99271a5
```

Result:

- Found build `4dcddeee-760e-4ca6-b2e7-5f6e2ae5a5c6`, platform `MAC_OS`, version `1.2 (11)`, processing state `VALID`, uploaded `2026-06-11T05:07:03-07:00`.
- Set export compliance `usesNonExemptEncryption=false`.
- Attached build `4dcddeee-760e-4ca6-b2e7-5f6e2ae5a5c6` to appStoreVersion `a8105b04-2b0d-4b5a-ad67-067af99271a5`.
- Created reviewSubmission `f3964a92-bcee-4500-a5f1-5d8b87246d29`.
- Submitted reviewSubmission `f3964a92-bcee-4500-a5f1-5d8b87246d29`.
- Final macOS appStoreVersion state: `WAITING_FOR_REVIEW`.
- Attached build: `4dcddeee-760e-4ca6-b2e7-5f6e2ae5a5c6`, number `11`, processing `VALID`, encryption `false`.

## Helper Skill

- Created local Codex skill: `/Users/vishaljain/.codex/skills/hold-distribution/SKILL.md`.
- Created helper script: `/Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh`.
