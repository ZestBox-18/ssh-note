#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN=$(swift build -c release --show-bin-path)
APP=dist/SSHNote.app
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/SSHNote" "$APP/Contents/MacOS/SSHNote"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SSHNote</string>
<key>CFBundleIdentifier</key><string>io.github.zestbox18.sshnote</string>
<key>CFBundleName</key><string>SSHNote</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
printf '本地构建完成：%s\n' "$APP"
