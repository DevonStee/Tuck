#!/bin/bash
# Builds build/Tuck.app. Tuck needs no permissions, so ad-hoc signing is enough.
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release

app="build/Tuck.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Tuck "$app/Contents/MacOS/Tuck"
# Compiles the Icon Composer project. Stderr only carries dyld noise from Xcode's tools;
# real problems come back on stdout as "error:" lines, which actool doesn't fail on.
icon_log="$(xcrun actool Resources/Tuck.icon \
    --compile "$app/Contents/Resources" \
    --output-format human-readable-text --errors \
    --output-partial-info-plist build/icon-partial.plist \
    --app-icon Tuck --include-all-app-icons \
    --target-device mac --minimum-deployment-target 14.0 --platform macosx \
    2>/dev/null)"
if grep -q "error:" <<<"$icon_log"; then
    grep "error:" <<<"$icon_log" >&2
    echo "Icon compilation failed." >&2
    exit 1
fi

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>local.tuck.app</string>
    <key>CFBundleName</key><string>Tuck</string>
    <key>CFBundleExecutable</key><string>Tuck</string>
    <key>CFBundleIconFile</key><string>Tuck</string>
    <key>CFBundleIconName</key><string>Tuck</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
echo "Built $app"
