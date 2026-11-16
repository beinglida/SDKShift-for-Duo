#!/bin/bash
# Build an UNSIGNED SDKShift.ipa for later (enterprise) re-signing.
# Run on macOS with Xcode 27.2 installed. Usage: ./build-unsigned-ipa.sh
set -euo pipefail
cd "$(dirname "$0")"

PROJECT="SDKShift.xcodeproj"
SCHEME="SDKShift"
CONFIG="Release"
BUILD_DIR="build"
DERIVED="$BUILD_DIR/DerivedData"

echo "==> Xcode: $(xcodebuild -version | tr '\n' ' ')"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
exec > >(tee "$BUILD_DIR/build.log") 2>&1

echo "==> Compiling (code signing disabled)..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED" \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP_PATH="$DERIVED/Build/Products/$CONFIG-iphoneos/$SCHEME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: build product not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Packaging unsigned IPA..."
rm -rf "$BUILD_DIR/Payload"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP_PATH" "$BUILD_DIR/Payload/"
( cd "$BUILD_DIR" && /usr/bin/zip -qr "$SCHEME-unsigned.ipa" Payload )

echo "==> Done: $BUILD_DIR/$SCHEME-unsigned.ipa"
ls -lh "$BUILD_DIR/$SCHEME-unsigned.ipa"
