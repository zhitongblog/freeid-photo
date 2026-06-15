#!/usr/bin/env bash
# One-command App Store release for FreeID Photo.
#   scripts/asc/release.sh <marketingVersion> <buildNumber>
#   e.g. scripts/asc/release.sh 1.1 14
#
# Bumps the version, archives + exports + uploads the build, waits for Apple to finish
# processing it, then runs release.mjs to apply all metadata and submit for review
# (auto-release after approval). Requires: xcodegen, Xcode, node, and the ASC .p8 key in
# ~/.appstoreconnect/private_keys (see asc.mjs CONFIG).
set -euo pipefail
MKT="${1:?usage: release.sh <marketingVersion> <buildNumber>}"
BUILD="${2:?usage: release.sh <marketingVersion> <buildNumber>}"
TEAM=6NQM3XP5RF
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "==> Bump project.yml to $MKT ($BUILD)"
sed -i '' "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"$MKT\"/" project.yml
sed -i '' "s/CURRENT_PROJECT_VERSION: \"[^\"]*\"/CURRENT_PROJECT_VERSION: \"$BUILD\"/" project.yml
xcodegen generate >/dev/null

echo "==> Test"
swift test 2>&1 | grep -E "Executed [0-9]+ tests" | tail -1

echo "==> Archive + export + upload"
rm -rf /tmp/FreeIDPhoto.xcarchive /tmp/freeid_export
xcodebuild -project FreeIDPhoto.xcodeproj -scheme FreeIDPhoto -configuration Release \
  -destination 'generic/platform=iOS' -archivePath /tmp/FreeIDPhoto.xcarchive \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=$TEAM archive >/dev/null
xcodebuild -exportArchive -archivePath /tmp/FreeIDPhoto.xcarchive \
  -exportPath /tmp/freeid_export -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates >/dev/null
xcrun altool --upload-app -f /tmp/freeid_export/FreeIDPhoto.ipa -t ios \
  --apiKey "${ASC_KEY_ID:-H85Q4NJPVD}" --apiIssuer "${ASC_ISSUER:-21dd1b35-fb04-42f1-8ec0-d847838fa7b6}" | tail -3

echo "==> Wait for build $BUILD to finish processing (VALID)…"
node "$ROOT/scripts/asc/wait-build.mjs" "$BUILD"

echo "==> Apply metadata + submit"
node "$ROOT/scripts/asc/release.mjs" "$MKT" "$BUILD"
