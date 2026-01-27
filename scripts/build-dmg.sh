#!/bin/bash
set -e

# Configuration
APP_NAME="GitFlow"
SCHEME="GitFlow"
PROJECT="GitFlow.xcodeproj"
BUILD_DIR="build"
DMG_DIR="dmg_contents"

# Get version from argument or project
VERSION=${1:-$(grep -m1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" | sed 's/.*= //' | sed 's/;//')}

echo "Building $APP_NAME version $VERSION..."

# Clean previous builds
rm -rf "$BUILD_DIR" "$DMG_DIR" "${APP_NAME}-${VERSION}.dmg"

# Build the app (Universal Binary: arm64 + x86_64)
echo "Compiling..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -arch arm64 -arch x86_64 \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Verify it's a universal binary
echo "Verifying universal binary..."
lipo -info "$APP_PATH/Contents/MacOS/$APP_NAME"

# Create DMG
echo "Creating DMG..."
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG with nice styling
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_NAME"

# Calculate checksum
echo "Calculating SHA256..."
shasum -a 256 "$DMG_NAME" | tee "${DMG_NAME}.sha256"

# Cleanup
rm -rf "$BUILD_DIR" "$DMG_DIR"

echo ""
echo "Done! Created:"
echo "  - $DMG_NAME"
echo "  - ${DMG_NAME}.sha256"
echo ""
echo "SHA256: $(cat ${DMG_NAME}.sha256 | awk '{print $1}')"
