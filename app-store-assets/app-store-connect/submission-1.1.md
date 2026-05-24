# Hold 1.1 Submission Log

## Target

- App Store Connect app id: `6755408368`
- Bundle id: `com.vishaljain.HoldApp`
- Locale: `en-GB`
- iOS appStoreVersion: `6ccfefb5-a49f-417d-b154-b5fbd11040fd`
- macOS appStoreVersion: `dd41569d-5050-4794-a1de-a9876ab098b4`
- Marketing version: `1.1`
- iOS build number: `9`
- macOS build number: `10`

## Local Inputs

- App Store metadata: `ios-listing.md`, `macos-listing.md`
- App Store preflight: `preflight-1.1.json`
- iOS export options: `export-ios-app-store.plist`
- macOS export options: `export-macos-app-store.plist`
- App Store Connect private key: `/Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8`

## Archive Commands

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project HoldApp.xcodeproj -scheme HoldApp-iOS -configuration Release -destination 'generic/platform=iOS' -archivePath /private/tmp/HoldAppRelease-1.1-Xcode26/Hold-iOS.xcarchive -derivedDataPath /private/tmp/HoldAppRelease-1.1-Xcode26/DerivedData -allowProvisioningUpdates -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 -authenticationKeyID NA9CQQGYY9 -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403 archive
```

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project HoldApp.xcodeproj -scheme HoldApp -configuration Release -destination 'generic/platform=macOS' -archivePath /private/tmp/HoldAppRelease-1.1-Xcode26/Hold-macOS.xcarchive -derivedDataPath /private/tmp/HoldAppRelease-1.1-Xcode26/DerivedData -allowProvisioningUpdates -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 -authenticationKeyID NA9CQQGYY9 -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403 archive
```

## Upload Commands

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -exportArchive -archivePath /private/tmp/HoldAppRelease-1.1-Xcode26/Hold-iOS.xcarchive -exportOptionsPlist app-store-assets/app-store-connect/export-ios-app-store.plist -exportPath /private/tmp/HoldAppRelease-1.1-Xcode26/ios-upload -allowProvisioningUpdates -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 -authenticationKeyID NA9CQQGYY9 -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403
```

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -exportArchive -archivePath /private/tmp/HoldAppRelease-1.1-Xcode26/Hold-macOS.xcarchive -exportOptionsPlist app-store-assets/app-store-connect/export-macos-app-store.plist -exportPath /private/tmp/HoldAppRelease-1.1-Xcode26/macos-upload -allowProvisioningUpdates -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 -authenticationKeyID NA9CQQGYY9 -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403
```

## Submission Command

```sh
ruby scripts/app_store_release_submit.rb --key-id NA9CQQGYY9 --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 --wait-minutes 1 --apply
```

## Status

- Created: May 24, 2026.
- The first iOS upload attempt from the selected Xcode 16.4 developer directory failed App Store Connect validation because it used the iOS 18.5 SDK. Rebuilt with `/Applications/Xcode.app` Xcode 26.3 and the iOS 26.2 SDK.
- iOS archive succeeded at `/private/tmp/HoldAppRelease-1.1-Xcode26/Hold-iOS.xcarchive`.
- iOS upload succeeded; App Store Connect build `d814d95b-85e7-43a3-b915-cc3789e93abf`, version `1.1 (9)`, reached `VALID`.
- macOS archive succeeded at `/private/tmp/HoldAppRelease-1.1-Xcode26/Hold-macOS.xcarchive`.
- macOS upload succeeded; App Store Connect build `ed07b1c7-d04a-464c-8e09-b772c101a943`, version `1.1 (10)`, reached `VALID`.
- iOS export compliance was set to `usesNonExemptEncryption=false`, build `9` was attached, and review submission `f8cdfb92-ac92-4553-99e8-490ba82bc22e` moved the appStoreVersion to `WAITING_FOR_REVIEW`.
- macOS export compliance was set to `usesNonExemptEncryption=false`, build `10` was attached, and review submission `870d7fc7-dece-4982-8b64-7da203e670b8` moved the appStoreVersion to `WAITING_FOR_REVIEW`.
- Daily approval monitor automation `monitor-hold-1-1-app-review` was created to inspect both `1.1` App Store versions until approval.
