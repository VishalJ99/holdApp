# DATA.md

- `app-store-assets/branding/` - Synced Hold brand package from `/Users/vishaljain/hold_branding`, including source ZIP/PDF/font files, extracted logo assets, and icon regeneration notes.
- `app-store-assets/app-store-connect/` - Platform-specific App Store Connect handoff files for iOS and macOS, API update docs, retained live preflight report, and reproduction notes for App Store Connect update workflows.
- `app-store-assets/app-store-connect/landing-preview.html` - Generated local App Store product-page preview for comparing iOS and macOS listing copy, screenshots, icons, and field-length meters before App Store Connect submission.
- `app-store-assets/app-store-connect/submission-1.1.md` - Release submission log for the iOS/macOS `1.1` binary archive, upload, and App Review workflow.
- `app-store-assets/app-store-connect/submission-1.2-ios.md` - Release submission log for the iOS-only `1.2` build `10` archive, upload, and App Review workflow.
- `app-store-assets/app-store-connect/submission-1.2-macos.md` - Release submission log for the macOS-only `1.2` build `11` archive, upload, keychain unlock handling, and App Review workflow.
- `app-store-assets/app-store-connect/submission-1.3-macos.md` - Release submission log for the macOS-only `1.3` build `12` archive, upload, keychain unlock handling, and App Review workflow.
- `app-store-assets/app-store-connect/submission-1.4-macos.md` - Release submission log for the macOS-only `1.4` build `13` archive, upload, keychain unlock handling, and App Review workflow.
- `app-store-assets/app-store-connect/export-ios-app-store.plist` and `app-store-assets/app-store-connect/export-macos-app-store.plist` - Xcode App Store Connect upload export options for the `1.1` iOS and macOS archives.
- `app-store-assets/screenshots/` - Generated App Store Connect screenshot assets for iPhone, iPad, and Mac; regenerate with `app-store-assets/generate_screenshots.sh`.
- `HoldApp/Assets.xcassets/hold_icon.imageset/` - Generated macOS menu-bar template icon variants for the Hold status item; regenerate with `app-store-assets/branding/generate_icons.sh`.
- `app-store-assets/metadata.md` - Paste-ready iOS and Mac App Store listing copy, review notes, keyword fields, and asset references.
- `release_guide.md` - High-level Hold release playbook covering local landing-page preview, metadata validation, Xcode 26 archive/upload, App Store Connect submission, monitoring, and closeout checks.
- `scripts/app_store_connect_update.rb` - Local Ruby App Store Connect API updater that validates the handoff markdown, dry-runs live record selection, patches version metadata only with `--apply`, and can replace inherited screenshots on editable versions with `--replace-screenshots`.
- `scripts/generate_app_store_preview.rb` - Local Ruby generator for `app-store-assets/app-store-connect/landing-preview.html`, using the platform listing markdown and current screenshot/icon assets as source input.
- `scripts/app_store_release_submit.rb` - Local Ruby App Store Connect release helper that inspects uploaded build attachment state, waits for valid builds, sets export compliance, attaches builds to `appStoreVersion` records, and submits through the current `reviewSubmissions`/`reviewSubmissionItems` API flow.
- `scripts/set_app_release_version.rb` - Local Ruby helper for dry-running and applying iOS/macOS app target `MARKETING_VERSION` updates in `HoldApp.xcodeproj/project.pbxproj` while leaving test targets untouched.
- `scripts/verify_app_store_assets.rb` - Local Ruby validator for App Store screenshot dimensions/alpha, marketing icon dimensions/alpha, menu-bar template alpha, and referenced app icon asset-catalog slots.
