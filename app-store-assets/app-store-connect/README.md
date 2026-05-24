# App Store Connect Handoff

This directory splits the refreshed Hold App Store metadata into platform-specific paste targets for App Store Connect.

Source of truth:
- `../metadata.md`
- `../branding/DESIGN.md`
- `../branding/source/Brand Guidelines.pdf`

Current live-state notes:
- Browser sessions still redirect to App Store Connect login, but an API key is available locally at `/Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8`.
- App Store Connect is configured with locale `en-GB` for the live Hold records.
- The current iOS and macOS `1.0` App Store versions are `READY_FOR_SALE`; full version metadata and screenshot changes require a new editable version. The live promotional text can be updated through the constrained API path documented in `api-update.md`.
- On May 23, 2026, the constrained API path updated the live iOS and macOS `en-GB` promotional text fields from `ios-listing.md` and `macos-listing.md`.
- On May 24, 2026, the API path created editable iOS and macOS `1.1` versions, patched their `en-GB` version metadata and review notes, and uploaded branded screenshots for `APP_IPHONE_65`, `APP_IPAD_PRO_3GEN_129`, and `APP_DESKTOP`.
- `preflight-1.1.json` is the retained machine-readable report for the current live state and the repeatable update plan; regenerate it with the command in `reproduction.txt`.
- `landing-preview.html` is the generated local iOS/macOS App Store product-page preview; regenerate it with `ruby scripts/generate_app_store_preview.rb`.
- The iOS and macOS app targets now use `MARKETING_VERSION = 1.1`; iOS build number is `9` and macOS build number is `10`.
- App Store archive/upload commands should use Xcode 26 from `/Applications/Xcode.app`; the selected developer directory may point at an older Xcode that fails upload validation with an outdated iOS SDK.
- Release submission automation should use `scripts/app_store_release_submit.rb`, which submits through `reviewSubmissions` and `reviewSubmissionItems`. Do not use the deprecated `appStoreVersionSubmissions` create endpoint.

Editable `1.1` App Store records:
- iOS appStoreVersion: `6ccfefb5-a49f-417d-b154-b5fbd11040fd`
- macOS appStoreVersion: `dd41569d-5050-4794-a1de-a9876ab098b4`
- Screenshot upload verification: iPhone `94804` bytes, iPad `105090` bytes, Mac `94189` bytes, all `COMPLETE`.
- Submission verification on May 24, 2026: iOS `1.1 (9)` build `d814d95b-85e7-43a3-b915-cc3789e93abf` and macOS `1.1 (10)` build `ed07b1c7-d04a-464c-8e09-b772c101a943` are attached, `VALID`, export-compliance `usesNonExemptEncryption=false`, and both appStoreVersions are `WAITING_FOR_REVIEW`.

Before saving changes in App Store Connect:
- Confirm the correct app record is selected for Hold.
- Apply the iOS fields from `ios-listing.md` to the iOS app/version page.
- Apply the macOS fields from `macos-listing.md` to the Mac app/version page.
- Upload screenshots from `../screenshots/`.
- Confirm before the final Save, Submit, or Resubmit action.

Assets:
- iOS screenshots: `../screenshots/hold-iphone-65.png`, `../screenshots/hold-ipad-129.png`
- Mac screenshot: `../screenshots/hold-mac-desktop.png`
- iOS marketing icon: `../../HoldApp-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon~ios-marketing.png`
- macOS marketing icon: `../../HoldApp/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png`

Brand rules copied from the synced package:
- Primary brand color: `#1F2747`
- Dark text/surface color: `#1F2937`
- White: `#FFFFFF`
- Use the full logo on light backgrounds and the white logo on dark backgrounds.
- Do not rotate, stretch, recolor, outline, shadow, or remove the icon from the logo.
