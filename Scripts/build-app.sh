#!/bin/bash
#
# Builds UMLExpress.app: release build, app bundle, icon, ad-hoc signature and a DMG.
#
# Usage: Scripts/build-app.sh [--no-dmg]
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
VERSION="${UML_EXPRESS_VERSION:-0.1.0}"
BUILD="$ROOT/build"
APP="$BUILD/UMLExpress.app"
BUNDLE_ID="com.umlexpress.app"
MAKE_DMG=1
[ "${1:-}" = "--no-dmg" ] && MAKE_DMG=0

echo "==> Building (release)"
# Project-local caches: SwiftPM's nested sandbox and the system module cache are not
# always writable (e.g. inside an agent sandbox).
export TMPDIR="$ROOT/.build/tmp"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/mc"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/mc"
mkdir -p "$TMPDIR" "$CLANG_MODULE_CACHE_PATH"
SWIFT_FLAGS=(-c release --disable-sandbox --scratch-path "$ROOT/.build")
swift build "${SWIFT_FLAGS[@]}" --product UMLExpressApp

BINARY="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)/UMLExpressApp"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/UMLExpress"

echo "==> Resources"
# SwiftPM emits the resources of a library target as a resource bundle next to the binary;
# `Bundle.module` looks for it in the app's resource directory as well.
BIN_PATH="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"
shopt -s nullglob
BUNDLES=("$BIN_PATH"/UMLExpress_*.bundle)
shopt -u nullglob
if [ ${#BUNDLES[@]} -eq 0 ]; then
    echo "warning: no resource bundles found in $BIN_PATH" >&2
else
    for bundle in "${BUNDLES[@]}"; do
        cp -R "$bundle" "$APP/Contents/Resources/"
    done
    # The action icons are also installed flat, which is the location `IconCatalog` checks
    # first: SwiftPM's bundle accessor expects the bundle next to the executable, not in
    # the resources directory of an app.
    if [ -d "$BIN_PATH/UMLExpress_UMLStudio.bundle/Icons16" ]; then
        cp -R "$BIN_PATH/UMLExpress_UMLStudio.bundle/Icons16" "$APP/Contents/Resources/"
    fi
fi

echo "==> Icon"
ICON_WORK="$BUILD/icon"
rm -rf "$ICON_WORK"
mkdir -p "$ICON_WORK"
if [ ! -x "$BUILD/make-icon" ]; then
    CLANG_MODULE_CACHE_PATH="$ROOT/.build/mc" swiftc -module-cache-path "$ROOT/.build/mc" \
        -o "$BUILD/make-icon" Scripts/make-icon.swift
fi
"$BUILD/make-icon" "$ICON_WORK" > /dev/null
iconutil -c icns "$ICON_WORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>UMLExpress</string>
    <key>CFBundleDisplayName</key>
    <string>UMLExpress</string>
    <key>CFBundleExecutable</key>
    <string>UMLExpress</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>GPL-3. Derived from JetUML (C) McGill University.</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>UMLExpress Diagram</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>${BUNDLE_ID}.diagram</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>${BUNDLE_ID}.diagram</string>
            <key>UTTypeDescription</key>
            <string>UMLExpress Diagram</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.json</string>
                <string>public.data</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>jet</string>
                </array>
                <key>public.mime-type</key>
                <string>application/vnd.umlexpress.diagram+json</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist" > /dev/null

echo "==> Codesign (ad-hoc; replace '-' with a Developer ID for distribution)"
codesign --force --deep --options runtime --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

if [ "$MAKE_DMG" = "1" ]; then
    echo "==> DMG"
    DMG="$BUILD/UMLExpress-${VERSION}.dmg"
    rm -f "$DMG"
    # hdiutil needs access to disk-image devices; some sandboxes deny it. Failure here is
    # reported but does not invalidate the app bundle.
    if hdiutil create -volname "UMLExpress" -srcfolder "$APP" -ov -format UDZO "$DMG" > /dev/null 2>&1; then
        echo "DMG: $DMG ($(du -h "$DMG" | cut -f1))"
    else
        echo "WARNING: hdiutil could not create the DMG (sandboxed environment?)."
        echo "         Run this script from a normal terminal, or use:"
        echo "         hdiutil create -volname UMLExpress -srcfolder \"$APP\" -ov -format UDZO \"$DMG\""
    fi
fi

echo "App bundle: $APP"
du -sh "$APP"
