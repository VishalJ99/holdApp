# Hold macOS 1.7 (16) TestFlight release

Ticket: PER-600 (parent PER-474)
Date: 2026-10-25
Source: 23b2fcf87511c9e40eb7e3d1aaea41ada0724c8e
Scope: macOS entry-chord routing and local MacBook update; iOS remains 1.2 (10). No public App Store submission was requested. External TestFlight Beta App Review was submitted after the user requested a friend download link.

## Source and verification

The MacBook checkout `/Users/vishaljain/xcode_projects/HoldApp` at f84e8dd was newer than the mini checkout and remote main. The installed 1.6 (15) binary contained protected Entry Chord capture, so outdated code alone did not explain the report. The patch handles modified entry keys through `performKeyEquivalent` and restarts capture when Spotlight regains key status. Existing untracked `previews/` assets were preserved.

`bash scripts/test-entry-chord-routing.sh` fails all six checks against the original panel and passes all six against the patch on MacBook. Independent Astra high review repeated the checks and reported localized surface PASS. These tests cover actual NSPanel routing with a stub controller and capture setup attempts; they do not establish physical OS shortcut suppression or task creation behavior.

## Build authority

Mac mini Xcode 27 could not compile an existing redundant Equatable conformance in OutlineView. The release uses the established MacBook Xcode 26 workflow: Xcode 26.6, build 17F113, at `/Applications/Xcode.app`. No unrelated compatibility change was made.

The existing signing keychain was temporarily selected for archive/export; the release runner restores the prior search list and default in `finally`. Credentials are not part of this record.

Working artifacts on MacBook: `/private/tmp/HoldAppRelease-PER-600-1.7-16/`.

## Archive and upload

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project HoldApp.xcodeproj -scheme HoldApp -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath /private/tmp/HoldAppRelease-PER-600-1.7-16/Hold-macOS.xcarchive \
  -derivedDataPath /private/tmp/HoldAppRelease-PER-600-1.7-16/DerivedData \
  -allowProvisioningUpdates \
  -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  -authenticationKeyID NA9CQQGYY9 \
  -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403 \
  CODE_SIGN_STYLE=Automatic 'CODE_SIGN_IDENTITY=Apple Development' archive

/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -exportArchive \
  -archivePath /private/tmp/HoldAppRelease-PER-600-1.7-16/Hold-macOS.xcarchive \
  -exportOptionsPlist app-store-assets/app-store-connect/export-macos-app-store.plist \
  -exportPath /private/tmp/HoldAppRelease-PER-600-1.7-16/macos-upload \
  -allowProvisioningUpdates \
  -authenticationKeyPath /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  -authenticationKeyID NA9CQQGYY9 \
  -authenticationKeyIssuerID b448403b-58ff-4d88-a7ea-271ecaec8403
```

Confirmed: `archive.log` reports `ARCHIVE SUCCEEDED`; archived Info.plist reports 1.7 (16); `codesign --verify --deep --strict` passes on MacBook.

Confirmed: `upload.log` reports `Upload succeeded`, `Uploaded HoldApp`, and `EXPORT SUCCEEDED` at 14:43:29 local MacBook time. Apple accepted the package for processing.

## TestFlight and local deployment

Confirmed through App Store Connect: build `c10b6326-e4f5-4911-bc58-9b90aaada33a` is MAC_OS 1.7 (16), `VALID`, not expired, with `usesNonExemptEncryption=false`. Internal state is `READY_FOR_BETA_TESTING`. GET of internal Alpha (`d0972dd7-7f29-4a4a-b9d8-d2cdf7efe5d3`) builds includes build 16.

The user then requested a friend invitation. Existing external Alpha (`bbdd4eb1-62f5-489c-a2e6-77fc8639b84f`) has public link enabled at https://testflight.apple.com/join/kUBeZDA4. Build 16 was attached (HTTP 204), and GET of the group's builds confirmed membership. Beta App Review submission returned HTTP 201. Latest state: external `WAITING_FOR_BETA_REVIEW`, submission `WAITING_FOR_REVIEW` (submittedDate `2026-10-25T08:03:25-07:00`). Friends cannot yet install the new build. en-GB test notes were updated through localization `1f67820d-af95-4883-ac18-5ed365474fb1`. No public App Store version was submitted.

Confirmed on MacBook: quit the old app; retained it as `/private/tmp/HoldApp-PER600-original-1.6-15.app`; copied the archive app to `/Applications/Hold.app`; strict deep signature verification passed; Info.plist reports 1.7 (16). The running process uses `/Applications/Hold.app/Contents/MacOS/Hold` (latest normal launch PID 76127). The designated signing requirement matches the prior app. A temporary diagnostic launch was ended and the app relaunched normally.

Physical keyboard behavior remains unverified. MacBook screenshot capture repeatedly timed out through the bridge; local CoreGraphics capture returned `CGDisplayCreateImage returned nil`, despite an unlocked console. No task-creation or real keyboard success is claimed.

Next actions: query the build's `betaAppReviewSubmission` and `buildBetaDetail` until Apple approves external testing; then verify installation from the public link on a friend's Mac. On the MacBook, verify Control+Enter routing and hold Cmd+Tab+Enter, including after focus loss/regain. No automatic monitor was created.

