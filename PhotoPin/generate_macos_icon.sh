#!/bin/bash

# PhotoPin macOS 앱 아이콘 생성 스크립트
# 원본 이미지에서 macOS 앱에 필요한 .icns 파일을 생성합니다

echo "🎨 PhotoPin macOS 앱 아이콘 생성 시작..."

# 원본 이미지 경로
SOURCE_IMAGE="/Users/munkyo/works/ai-code/photo/images/logo-ori.png"
OUTPUT_DIR="/Users/munkyo/works/ai-code/photo/PhotoPin"
ICONSET_DIR="$OUTPUT_DIR/AppIcon.iconset"
ICNS_FILE="$OUTPUT_DIR/AppIcon.icns"

# 원본 이미지 확인
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ 원본 이미지를 찾을 수 없습니다: $SOURCE_IMAGE"
    exit 1
fi

# iconset 디렉토리 생성
mkdir -p "$ICONSET_DIR"

echo "📁 작업 디렉토리: $ICONSET_DIR"

# macOS 아이콘 크기 정의
# macOS Big Sur 이후 필요한 크기들
ICON_SIZES=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

# 각 크기별로 아이콘 생성
for SIZE_CONFIG in "${ICON_SIZES[@]}"; do
    IFS=':' read -r SIZE FILENAME <<< "$SIZE_CONFIG"
    
    echo "🔄 생성 중: $FILENAME (${SIZE}x${SIZE})"
    
    # sips를 사용하여 리사이즈
    sips -z "$SIZE" "$SIZE" "$SOURCE_IMAGE" --out "$ICONSET_DIR/$FILENAME" > /dev/null 2>&1
done

echo ""
echo "📦 .icns 파일 생성 중..."

# iconutil을 사용하여 .icns 파일 생성
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"

if [ -f "$ICNS_FILE" ]; then
    echo "✅ macOS 앱 아이콘 생성 완료!"
    echo "📍 위치: $ICNS_FILE"
    
    # iconset 디렉토리 정리 (선택적)
    echo ""
    read -p "🗑️  임시 파일을 삭제하시겠습니까? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$ICONSET_DIR"
        echo "✅ 임시 파일 삭제 완료"
    fi
else
    echo "❌ .icns 파일 생성 실패"
    exit 1
fi

echo ""
echo "🔨 macOS 앱에 적용 방법:"
echo "1. Info.plist 파일에 다음 줄 추가:"
echo "   <key>CFBundleIconFile</key>"
echo "   <string>AppIcon</string>"
echo ""
echo "2. 빌드 시 AppIcon.icns를 Resources에 포함"
echo ""
echo "또는"
echo ""
echo "3. Xcode 프로젝트의 경우:"
echo "   - Assets.xcassets에 AppIcon 추가"
echo "   - 생성된 .icns 파일을 드래그 앤 드롭"

# build_app.sh 업데이트 제안
if [ -f "$OUTPUT_DIR/build_app.sh" ]; then
    echo ""
    echo "💡 build_app.sh 스크립트 업데이트 제안:"
    echo "   리소스 복사 부분에 다음 추가:"
    echo "   cp AppIcon.icns \"\$APP_DIR/Contents/Resources/\""
fi