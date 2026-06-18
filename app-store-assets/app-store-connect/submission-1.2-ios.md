# Hold 1.2 iOS Submission Log

## Target

- App Store Connect app id: `6755408368`
- Bundle id: `com.vishaljain.HoldApp`
- Locale: `en-GB`
- Platform: iOS only
- Marketing version: `1.2`
- iOS build number: `10`
- macOS release state: no new macOS upload; macOS `1.2` build `11` is already `READY_FOR_SALE`

## Local Inputs

- App Store metadata: `ios-listing.md`
- App Store preflight: pending
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
