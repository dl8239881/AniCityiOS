#!/usr/bin/env bash
# Builds an unsigned AniCity.ipa (Payload/AniCity.app) for sideload tools
# such as appdb that re-sign on device. No Apple certificate required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is not installed. brew install xcodegen" >&2
  exit 1
fi

xcodegen generate --spec "$ROOT/project.yml"

DERIVED="$ROOT/build/DerivedData"
rm -rf "$DERIVED"

xcodebuild \
  -project "$ROOT/AniCity.xcodeproj" \
  -scheme AniCity \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS=arm64 \
  build

APP="$(find "$DERIVED/Build/Products" -type d -name 'AniCity.app' | head -n 1)"
if [[ -z "${APP}" || ! -d "${APP}" ]]; then
  echo "AniCity.app was not produced" >&2
  find "$DERIVED/Build/Products" -maxdepth 3 -type d >&2 || true
  exit 1
fi

echo "App bundle: $APP"

STAGE="$ROOT/build/Payload"
rm -rf "$STAGE" "$ROOT/build/AniCity.ipa"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/AniCity.app"
chmod +x "$STAGE/AniCity.app/AniCity" || true
# appdb re-signs. Strip any signature Xcode still embedded.
codesign --remove-signature "$STAGE/AniCity.app" >/dev/null 2>&1 || true
find "$STAGE/AniCity.app" -name '_CodeSignature' -type d -prune -exec rm -rf {} + || true
rm -f "$STAGE/AniCity.app/embedded.mobileprovision" || true

(
  cd "$ROOT/build"
  zip -qry -X AniCity.ipa Payload
)

test -f "$ROOT/build/AniCity.ipa"
echo "---- IPA ----"
ls -lh "$ROOT/build/AniCity.ipa"
echo "---- bundle exec ----"
file "$STAGE/AniCity.app/AniCity"
echo "---- zip listing (head) ----"
unzip -l "$ROOT/build/AniCity.ipa" | head -n 40

# Sanity: unsigned zip with the expected layout, arm64 Mach-O, no signature.
unzip -l "$ROOT/build/AniCity.ipa" | grep -q "Payload/AniCity.app/Info.plist"
unzip -l "$ROOT/build/AniCity.ipa" | grep -q "Payload/AniCity.app/AniCity"
file "$STAGE/AniCity.app/AniCity" | grep -q "arm64"
if codesign -d "$STAGE/AniCity.app" >/dev/null 2>&1; then
  echo "Expected the packaged app to be unsigned" >&2
  exit 1
fi
echo "Unsigned AniCity.ipa is ready."
