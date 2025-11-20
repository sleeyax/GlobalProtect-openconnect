#!/bin/bash
set -e

# This script builds the AppImage package for GlobalProtect-openconnect
# It is designed to be run from the workspace root directory in a Docker container

ARCH=$(uname -m)
WORKSPACE=${WORKSPACE:-/workspace}
BUILD_DIR="$WORKSPACE/.build/appimage"

cd "$WORKSPACE"

echo "Building AppImage for $ARCH architecture..."

# Extract and build the application
if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
fi

# Find and extract the tarball
TARBALL=$(find . -maxdepth 1 -name "*.tar.gz" -not -name "*offline*" | head -n 1)
if [ -z "$TARBALL" ]; then
    echo "Error: No tarball found"
    exit 1
fi

echo "Extracting $TARBALL..."
tar -xzf "$TARBALL" -C "$BUILD_DIR"

# Get the extracted directory name
EXTRACT_DIR=$(ls -d "$BUILD_DIR"/*/ | head -n 1)
cd "$EXTRACT_DIR"

echo "Building application..."
make build OFFLINE=0 BUILD_FE=0 INCLUDE_GUI=1

# Install into AppDir
APPDIR="$BUILD_DIR/AppDir"
echo "Installing to AppDir: $APPDIR"
make install DESTDIR="$APPDIR"

# Download linuxdeploy tools
cd "$BUILD_DIR"
echo "Downloading linuxdeploy for $ARCH..."

LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-${ARCH}.AppImage"
wget -c "$LINUXDEPLOY_URL" -O linuxdeploy.AppImage
chmod +x linuxdeploy.AppImage

# Download GTK plugin for proper theme support
echo "Downloading linuxdeploy-plugin-gtk..."
wget -c https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh
chmod +x linuxdeploy-plugin-gtk.sh

# Set environment variables for linuxdeploy
export DEPLOY_GTK_VERSION=3
export VERSION=${VERSION:-dev}

# Create AppImage
echo "Creating AppImage..."
./linuxdeploy.AppImage \
    --appdir "$APPDIR" \
    --plugin gtk \
    --executable "$APPDIR/usr/bin/gpclient" \
    --executable "$APPDIR/usr/bin/gpauth" \
    --executable "$APPDIR/usr/bin/gpservice" \
    --executable "$APPDIR/usr/bin/gpgui-helper" \
    --desktop-file "$APPDIR/usr/share/applications/gpgui.desktop" \
    --icon-file "$APPDIR/usr/share/icons/hicolor/scalable/apps/gpgui.svg" \
    --icon-file "$APPDIR/usr/share/icons/hicolor/32x32/apps/gpgui.png" \
    --icon-file "$APPDIR/usr/share/icons/hicolor/128x128/apps/gpgui.png" \
    --output appimage

# Find the generated AppImage
GENERATED_APPIMAGE=$(find . -maxdepth 1 -name "*.AppImage" -not -name "linuxdeploy*.AppImage" | head -n 1)

if [ -z "$GENERATED_APPIMAGE" ]; then
    echo "Error: AppImage generation failed"
    exit 1
fi

# Rename to standard naming convention
APPIMAGE_NAME="globalprotect-openconnect-${VERSION}-${ARCH}.AppImage"
mv "$GENERATED_APPIMAGE" "$APPIMAGE_NAME"

echo "AppImage created: $APPIMAGE_NAME"

# Generate sha256sum
sha256sum "$APPIMAGE_NAME" | cut -d' ' -f1 > "${APPIMAGE_NAME}.sha256"

# Move artifacts to the expected location
mkdir -p "$WORKSPACE/artifacts"
mv "$APPIMAGE_NAME" "$APPIMAGE_NAME.sha256" "$WORKSPACE/artifacts/"

echo "Build complete! Artifacts:"
ls -lh "$WORKSPACE/artifacts/"
