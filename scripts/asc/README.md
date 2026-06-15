# App Store release automation

One-command release to the App Store for **FreeID Photo** (app id `6779873542`), built
during the v1.0 submission and reusable for every future update.

## Release an update

```bash
scripts/asc/release.sh <marketingVersion> <buildNumber>
# e.g.
scripts/asc/release.sh 1.1 14
```

This will: bump `project.yml`, run tests, archive + export + upload the build via `altool`,
wait for Apple to finish processing it, then apply all metadata and **submit for review**
(set to **auto-release after approval**).

To stage everything but NOT submit (review it in the web UI first):

```bash
# build + upload yourself, then:
node scripts/asc/release.mjs 1.1 14 --no-submit
```

## Files

| file | what |
|---|---|
| `release.sh` | orchestrator: version bump → archive/export/upload → wait → `release.mjs` |
| `release.mjs` | ASC API flow: ensure version, apply metadata, age rating, review contact, attach build, upload screenshots, submit |
| `wait-build.mjs` | polls until the uploaded build is `VALID` |
| `asc.mjs` | ASC API helpers (ES256 JWT, `api()`, screenshot uploader) + non-secret IDs |
| `metadata.mjs` | **edit this** — name, subtitle (8 langs), description/keywords (en + zh), copyright, category, age rating, review contact, screenshot list |
| `screenshots/` | 6.9″ (1290×2796) marketing screenshots uploaded to each locale |
| `screenshots.swift` | regenerate the screenshots (`swift screenshots.swift`) |
| `privacy.html` | source of the privacy page deployed at doaipm.com/privacy |

## Editing common things

- **Release notes / what's new**: edit `whatsNew` in `metadata.mjs` (required for updates).
- **Description / keywords / subtitle**: edit `metadata.mjs`.
- **Screenshots**: replace the PNGs in `screenshots/` (or rerun `screenshots.swift`). A new
  version uploads them automatically; `release.mjs` skips upload if the version already has some.
- **Review contact / phone**: `reviewContact` in `metadata.mjs`.

## Prerequisites

- ASC API key `.p8` at `~/.appstoreconnect/private_keys/AuthKey_H85Q4NJPVD.p8`
  (key id `H85Q4NJPVD`, issuer `21dd1b35-…`, the "FreeID Photo CI" Admin key). The key is
  **never** committed. Override via `ASC_KEY_ID` / `ASC_ISSUER` / `ASC_APP_ID` / `ASC_KEY_PATH`.
- `xcodegen`, Xcode (signing team `6NQM3XP5RF`), Node ≥ 18.

## One-time setup (already done — carries across versions, NOT re-run by the script)

- App record + TestFlight + distribution signing.
- **Pricing**: Free, all territories.
- **App Privacy**: "Data Not Collected", published.
- **Privacy policy page**: `privacy.html` deployed to `doaipm.com/privacy` (repo
  `zhitongblog/doaipm`, `public/privacy/index.html`; Cloudflare auto-deploys).

If you ever need to redo App Privacy or pricing, those are quickest in the App Store Connect
web UI; everything else is in `release.mjs`.
