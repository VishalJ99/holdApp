# App Store Connect API Update

Use this path when browser login is unavailable and an App Store Connect API key is available.

## Key Setup

Keep the private key out of the repository.

Expected local key path:

```sh
/Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8
```

Current key file copied from `dross`:

```sh
rsync -av dross:/Users/dross/.private/appstoreconnect/AuthKey_NA9CQQGYY9.p8 /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8
chmod 600 /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8
```

Required non-secret values:

```sh
export ASC_KEY_ID="NA9CQQGYY9"
export ASC_ISSUER_ID="<issuer-id-from-App-Store-Connect>"
```

Optional values:

```sh
export ASC_APP_ID="<app-id-if-bundle-id-lookup-is-ambiguous>"
export ASC_BUNDLE_ID="com.vishaljain.HoldApp"
export ASC_LOCALE="en-GB"
```

## Local Validation

Validate the iOS and macOS handoff markdown without calling the network:

```sh
ruby scripts/app_store_connect_update.rb --local-check
```

This checks App Store field lengths and confirms the referenced screenshot/icon files exist locally.

Validate generated image dimensions and alpha requirements:

```sh
ruby scripts/verify_app_store_assets.rb
```

## Dry Run

Dry-run the live App Store Connect lookup and show which records would be patched:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id "$ASC_KEY_ID" \
  --issuer-id "$ASC_ISSUER_ID" \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --locale en-GB
```

The dry run does not mutate App Store Connect.

## Apply

Patch version-localized metadata and review notes for both platforms:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id "$ASC_KEY_ID" \
  --issuer-id "$ASC_ISSUER_ID" \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --locale en-GB \
  --apply
```

Do not use broad `--apply` against `READY_FOR_SALE` versions. Full description, keyword, screenshot, and review-note changes require an editable App Store version. For the current live v1.0 records, use only the constrained promotional-text path unless a new editable version has been created.

## Prepare Next Version

Align the local app target marketing versions before uploading binaries for the new App Store version:

```sh
ruby scripts/set_app_release_version.rb --version 1.1
ruby scripts/set_app_release_version.rb --version 1.1 --apply
```

The helper only targets the iOS and macOS app build configurations for `com.vishaljain.HoldApp`. It preserves current build numbers unless `--ios-build` or `--macos-build` is passed explicitly.

Dry-run creation of the next editable version:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id "$ASC_KEY_ID" \
  --issuer-id "$ASC_ISSUER_ID" \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --locale en-GB \
  --prepare-next-version 1.1
```

Create or update that editable version and write the staged full metadata:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id "$ASC_KEY_ID" \
  --issuer-id "$ASC_ISSUER_ID" \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --locale en-GB \
  --prepare-next-version 1.1 \
  --apply
```

This mode creates missing iOS/macOS App Store version records, creates missing `en-GB` version localizations with the staged metadata, and patches existing editable localizations/review notes when present. It does not upload binaries.

Create/update the editable version and upload staged screenshots:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id "$ASC_KEY_ID" \
  --issuer-id "$ASC_ISSUER_ID" \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --locale en-GB \
  --prepare-next-version 1.1 \
  --upload-screenshots \
  --apply
```

If App Store Connect has inherited screenshots from an earlier version on the editable record, replace only the editable-version screenshot records before uploading the staged files:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id "$ASC_KEY_ID" \
  --issuer-id "$ASC_ISSUER_ID" \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --locale en-GB \
  --prepare-next-version 1.1 \
  --upload-screenshots \
  --replace-screenshots \
  --apply
```

Verified screenshot display types:

- `hold-iphone-65.png` -> `APP_IPHONE_65`
- `hold-ipad-129.png` -> `APP_IPAD_PRO_3GEN_129`
- `hold-mac-desktop.png` -> `APP_DESKTOP`

The `1.1` editable iOS/macOS versions have been created, the `en-GB` localizations and review notes have been patched, and the branded screenshots have been uploaded with `--replace-screenshots` after App Store Connect inherited the old live screenshots.

The retained `1.1` preflight has no local marketing-version mismatch warnings after the iOS/macOS app targets were updated to `MARKETING_VERSION = 1.1`.

Write the retained preflight report:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id "$ASC_KEY_ID" \
  --issuer-id "$ASC_ISSUER_ID" \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --locale en-GB \
  --prepare-next-version 1.1 \
  --upload-screenshots \
  --replace-screenshots \
  --write-preflight app-store-assets/app-store-connect/preflight-1.1.json
```

Patch only the live promotional text:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id "$ASC_KEY_ID" \
  --issuer-id "$ASC_ISSUER_ID" \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --locale en-GB \
  --promotional-text-only \
  --apply
```

For the current live `1.0` records, the verified version IDs are:

- iOS: `31e15c85-fa32-4c27-8f20-562410142b37`
- macOS: `682ae6e0-d9d4-45b0-a354-08cfdffb0272`

Verify live record state and promotional text:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id "$ASC_KEY_ID" \
  --issuer-id "$ASC_ISSUER_ID" \
  --key-path /Users/vishaljain/.appstoreconnect/private_keys/AuthKey_NA9CQQGYY9.p8 \
  --locale en-GB \
  --inspect-live
```

If App Store Connect has multiple editable versions for a platform, pass the explicit version record:

```sh
ruby scripts/app_store_connect_update.rb \
  --key-id "$ASC_KEY_ID" \
  --issuer-id "$ASC_ISSUER_ID" \
  --locale en-GB \
  --ios-version-id "<ios-app-store-version-id>" \
  --macos-version-id "<macos-app-store-version-id>" \
  --apply
```

## Scope

The full metadata mode patches:

- Version description
- Keywords
- Promotional text
- Support URL
- What's new
- Review notes

It can also attempt app-level name, subtitle, and privacy policy URL with `--update-app-info`, but the current iOS and macOS handoff files intentionally use different subtitles, so subtitle should be reviewed manually before using that flag.

Binary/app-icon delivery remains a separate build upload action. Screenshots require an editable app version.
