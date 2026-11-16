#!/usr/bin/env bash
# Packages the Capacitor iOS app as an unsigned AniCity.ipa.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required (run this on a Mac)." >&2
  exit 1
fi

npm ci
npm run build
npx cap sync ios

cd "$ROOT/ios/App"
pod install

DERIVED="$ROOT/build/DerivedData"
rm -rf "$DERIVED"

xcodebuild \
  -workspace "$ROOT/ios/App/App.xcworkspace" \
  -scheme App \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS=arm64 \
  build

APP="$(find "$DERIVED/Build/Products" -type d -name 'App.app' | head -n 1)"
if [[ -z "${APP}" || ! -d "${APP}" ]]; then
  echo "App.app was not produced" >&2
  exit 1
fi

STAGE="$ROOT/build/Payload"
rm -rf "$STAGE" "$ROOT/build/AniCity.ipa"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/App.app"
chmod +x "$STAGE/App.app/App" || true
codesign --remove-signature "$STAGE/App.app" >/dev/null 2>&1 || true
find "$STAGE/App.app" -name '_CodeSignature' -type d -prune -exec rm -rf {} + || true
rm -f "$STAGE/App.app/embedded.mobileprovision" || true

(
  cd "$ROOT/build"
  zip -qry -X AniCity.ipa Payload
)

test -f "$ROOT/build/AniCity.ipa"
file "$STAGE/App.app/App" | grep -q arm64
if codesign -d "$STAGE/App.app" >/dev/null 2>&1; then
  echo "Expected the packaged app to be unsigned" >&2
  exit 1
fi
ls -lh "$ROOT/build/AniCity.ipa"
echo "Unsigned AniCity.ipa is ready."
