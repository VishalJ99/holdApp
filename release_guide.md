# Hold Release Guide

This is the release workflow for the Hold iOS and macOS App Store listings and binaries. It keeps marketing copy, screenshots, binary upload, App Review submission, and monitoring reproducible from the repo.

## Key Paths

- App Store Connect handoff: `app-store-assets/app-store-connect/`
- iOS listing source: `app-store-assets/app-store-connect/ios-listing.md`
- macOS listing source: `app-store-assets/app-store-connect/macos-listing.md`
- Landing-page preview: `app-store-assets/app-store-connect/landing-preview.html`
- App Store release log: `app-store-assets/app-store-connect/submission-1.1.md`
- App Store Connect API key path: `/Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8`
- Current app id: `6755408368`
- Bundle id: `com.vishaljain.HoldApp`
- Locale: `en-GB`

## 1. Iterate Landing Page Copy Locally

Edit copy in:

```sh
app-store-assets/app-store-connect/ios-listing.md
app-store-assets/app-store-connect/macos-listing.md
```

Regenerate the local preview:

```sh
ruby scripts/generate_app_store_preview.rb
```

Open:

```sh
open app-store-assets/app-store-connect/landing-preview.html
```

The preview reads the iOS and macOS listing markdown, embeds the current screenshots and icons, shows App Store-style product headers, screenshot order, promotional text, description, and field-length meters. Use the iOS/macOS segmented control to compare both pages. Use the scratchpad for quick wording experiments; edits there are not written back to the markdown.

## 2. Regenerate Brand Assets When Needed

Brand package source lives in:

```sh
app-store-assets/branding/
```

Regenerate app icons from the synced brand package:

```sh
bash app-store-assets/branding/generate_icons.sh
```

Regenerate App Store screenshots:

```sh
bash app-store-assets/generate_screenshots.sh
```

Validate generated assets:

```sh
ruby scripts/verify_app_store_assets.rb
```

## 3. Validate App Store Metadata

Run local listing validation:

```sh
ruby scripts/app_store_connect_update.rb --local-check
```

Generate a live preflight report without mutating App Store Connect:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id NA9CQQGYY9 \
  --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --locale en-GB \
  --prepare-next-version 1.1 \
  --upload-screenshots \
  --replace-screenshots \
  --write-preflight app-store-assets/app-store-connect/preflight-1.1.json
```

Apply metadata and screenshot updates only to an editable App Store version:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id NA9CQQGYY9 \
  --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --locale en-GB \
  --prepare-next-version 1.1 \
  --upload-screenshots \
  --replace-screenshots \
  --apply
```

## 4. Bump App Version And Build Numbers

Dry-run the Xcode project version update:

```sh
ruby scripts/set_app_release_version.rb --version 1.1 --ios-build 9 --macos-build 10
```

Apply it:

```sh
ruby scripts/set_app_release_version.rb --version 1.1 --ios-build 9 --macos-build 10 --apply
```

The helper targets only the iOS and macOS app build configurations for `com.vishaljain.HoldApp`; it avoids test targets.

## 5. Archive With Xcode 26

Use Xcode 26 explicitly. Do not rely on `xcode-select`, because it may point at an older Xcode in `~/Downloads` and App Store Connect can reject uploads built with an older iOS SDK.

Archive iOS:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project HoldApp.xcodeproj \
  -scheme HoldApp-iOS \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /private/tmp/HoldAppRelease-1.1-Xcode26/Hold-iOS.xcarchive \
  -derivedDataPath /private/tmp/HoldAppRelease-1.1-Xcode26/DerivedData \
  -allowProvisioningUpdates \
  -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  -authenticationKeyID NA9CQQGYY9 \
  -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403 \
  archive
```

Archive macOS:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project HoldApp.xcodeproj \
  -scheme HoldApp \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath /private/tmp/HoldAppRelease-1.1-Xcode26/Hold-macOS.xcarchive \
  -derivedDataPath /private/tmp/HoldAppRelease-1.1-Xcode26/DerivedData \
  -allowProvisioningUpdates \
  -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  -authenticationKeyID NA9CQQGYY9 \
  -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403 \
  archive
```

## 6. Upload Binaries

Upload iOS:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -exportArchive \
  -archivePath /private/tmp/HoldAppRelease-1.1-Xcode26/Hold-iOS.xcarchive \
  -exportOptionsPlist app-store-assets/app-store-connect/export-ios-app-store.plist \
  -exportPath /private/tmp/HoldAppRelease-1.1-Xcode26/ios-upload \
  -allowProvisioningUpdates \
  -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  -authenticationKeyID NA9CQQGYY9 \
  -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403
```

Upload macOS:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -exportArchive \
  -archivePath /private/tmp/HoldAppRelease-1.1-Xcode26/Hold-macOS.xcarchive \
  -exportOptionsPlist app-store-assets/app-store-connect/export-macos-app-store.plist \
  -exportPath /private/tmp/HoldAppRelease-1.1-Xcode26/macos-upload \
  -allowProvisioningUpdates \
  -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  -authenticationKeyID NA9CQQGYY9 \
  -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403
```

Wait for App Store Connect build processing to reach `VALID`.

## 7. Attach Builds And Submit For Review

Inspect current state:

```sh
ruby scripts/app_store_release_submit.rb \
  --key-id NA9CQQGYY9 \
  --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --inspect
```

Attach the expected builds, set export compliance to `usesNonExemptEncryption=false`, and submit:

```sh
ruby scripts/app_store_release_submit.rb \
  --key-id NA9CQQGYY9 \
  --issuer-id b448403b-58ff-4d88-a7ea-271ecaec8403 \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --wait-minutes 30 \
  --apply
```

The submission helper uses the current App Store Connect flow: attach the processed build to `appStoreVersions`, patch build export compliance, create or reuse `reviewSubmissions`, add the version through `reviewSubmissionItems`, then submit the review submission with `submitted=true`. Do not use deprecated `appStoreVersionSubmissions` create calls.

## 8. Verify And Monitor

After submission, `--inspect` should show:

- iOS version `1.1`, expected build number, build processing `VALID`, encryption `false`, state `WAITING_FOR_REVIEW` or later.
- macOS version `1.1`, expected build number, build processing `VALID`, encryption `false`, state `WAITING_FOR_REVIEW` or later.

The current monitor automation is:

```text
monitor-hold-1-1-app-review
```

It checks both submitted `1.1` App Store versions daily until Apple approves them or reports a blocker.

## 9. Close The Release

Before committing:

```sh
ruby -c scripts/app_store_connect_update.rb
ruby -c scripts/app_store_release_submit.rb
ruby -c scripts/generate_app_store_preview.rb
ruby -c scripts/set_app_release_version.rb
ruby scripts/app_store_connect_update.rb --local-check
ruby scripts/verify_app_store_assets.rb
git diff --check
```

Confirm `app-store-assets/app-store-connect/submission-1.1.md` records archive paths, build ids, review submission ids, final App Store state, and monitor id.

Commit with the release ticket or release objective in the body. Do not commit private key material.
