#!/bin/bash

# 앱 번들 생성 스크립트
APP_NAME="GeoTagger"
BUNDLE_DIR="dist/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# 기존 번들 제거
rm -rf "$BUNDLE_DIR"

# 디렉토리 구조 생성
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 실행 파일 복사
cp "GeoTagger/.build/arm64-apple-macosx/release/$APP_NAME" "$MACOS_DIR/"

# Python 스크립트 복사
cp "geotag.py" "$RESOURCES_DIR/"

# Info.plist 생성
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.hasselblad.geotagger</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>GeoTagger</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.photography</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2024 Hasselblad Tools</string>
</dict>
</plist>
EOF

# 아이콘 생성 (SF Symbols 사용)
cat > "$RESOURCES_DIR/create_icon.swift" << 'EOF'
import AppKit
import CoreGraphics

let size = CGSize(width: 512, height: 512)
let image = NSImage(size: size)

image.lockFocus()

// 배경 그라데이션
let gradient = NSGradient(colors: [
    NSColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0),
    NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0)
])
gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 135)

// 아이콘 그리기
let config = NSImage.SymbolConfiguration(pointSize: 200, weight: .medium)
if let symbol = NSImage(systemSymbolName: "location.magnifyingglass", 
                        accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    
    let symbolRect = NSRect(
        x: (size.width - 300) / 2,
        y: (size.height - 300) / 2,
        width: 300,
        height: 300
    )
    
    NSColor.white.setFill()
    symbol.draw(in: symbolRect, from: .zero, 
               operation: .sourceOver, fraction: 1.0)
}

image.unlockFocus()

// ICNS 생성
let icnsData = NSMutableData()
let imageRep = image.representations.first as? NSBitmapImageRep
if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "AppIcon.png"))
}
EOF

swift "$RESOURCES_DIR/create_icon.swift"
mv AppIcon.png "$RESOURCES_DIR/AppIcon.png"
rm "$RESOURCES_DIR/create_icon.swift"

# 실행 권한 설정
chmod +x "$MACOS_DIR/$APP_NAME"

# 코드 서명
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "✅ 앱 번들 생성 완료: $BUNDLE_DIR"
echo "📱 Finder에서 앱 실행: open $BUNDLE_DIR"