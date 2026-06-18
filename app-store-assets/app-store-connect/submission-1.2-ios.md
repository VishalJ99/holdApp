# Hold 1.2 iOS Submission Log

## Target

- App Store Connect app id: `6755408368`
- Bundle id: `com.vishaljain.HoldApp`
- Locale: `en-GB`
- Platform: iOS only
- iOS appStoreVersion: `72afe9c4-cf96-4b4c-8a9a-b11059d62881`
- Marketing version: `1.2`
- iOS build number: `10`
- macOS release state: no new macOS upload; macOS `1.2` build `11` is already `READY_FOR_SALE`

## Local Inputs

- App Store metadata: `ios-listing.md`
- App Store preflight: `prepare-version IOS 1.2`
- iOS export options: `export-ios-app-store.plist`
- App Store Connect private key: `/Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8`

## Archive Command

```sh
/Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh archive-upload IOS 1.2 10 /private/tmp/HoldAppRelease-1.2-IOS
```

## Submission Command

```sh
/Users/vishaljain/.codex/skills/hold-distribution/scripts/hold_distribution.sh submit IOS 1.2 10
```

## Status

- Created: June 18, 2026.
- Scope confirmed as iOS-only: live iOS `1.1` build `9` is `READY_FOR_SALE`; live macOS `1.2` build `11` is already `READY_FOR_SALE`.
- iOS App Store Connect version `1.2` was created as `72afe9c4-cf96-4b4c-8a9a-b11059d62881`.
- iOS archive succeeded at `/private/tmp/HoldAppRelease-1.2-IOS/Hold-iOS.xcarchive`.
- iOS upload succeeded; App Store Connect build `b8c1b915-d0f6-4e98-9c19-beb3bbfbb5db`, version `1.2 (10)`, reached `VALID`.
- iOS export compliance was set to `usesNonExemptEncryption=false`, build `10` was attached, and review submission `3afc1acc-de43-4329-88db-70dac3f3d083` moved the appStoreVersion to `WAITING_FOR_REVIEW`.
