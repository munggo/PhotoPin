#!/bin/bash

# 앱 이름과 경로 설정
APP_NAME="PhotoPin"
BUILD_DIR=".build/release"
DIST_DIR="../dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

# 기존 앱 번들 제거
rm -rf "$APP_BUNDLE"

# 앱 번들 디렉토리 구조 생성
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 실행 파일 복사
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Info.plist 복사
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

# 실행 권한 설정
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 코드 서명 (옵션)
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ $APP_NAME.app이 $DIST_DIR에 생성되었습니다."
echo "📍 실행: open $APP_BUNDLE"