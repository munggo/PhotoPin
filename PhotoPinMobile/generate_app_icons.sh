#!/bin/bash

# PhotoPin 앱 아이콘 생성 스크립트
# 원본 이미지에서 iOS 앱에 필요한 모든 크기의 아이콘을 생성합니다

echo "🎨 PhotoPin 앱 아이콘 생성 시작..."

# 원본 이미지 경로
SOURCE_IMAGE="/Users/munkyo/works/ai-code/photo/images/logo-ori.png"
ASSETS_PATH="/Users/munkyo/works/ai-code/photo/PhotoPinMobile/XcodeProject/PhotoPin/Assets.xcassets"
ICON_SET_PATH="$ASSETS_PATH/AppIcon.appiconset"

# 원본 이미지 확인
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ 원본 이미지를 찾을 수 없습니다: $SOURCE_IMAGE"
    exit 1
fi

# Assets 디렉토리 생성
mkdir -p "$ICON_SET_PATH"

echo "📁 아이콘셋 경로: $ICON_SET_PATH"

# iOS 앱 아이콘 크기 정의
# Format: size:scale:idiom:filename
ICON_SIZES=(
    # iPhone Notification
    "20:2:iphone:40"
    "20:3:iphone:60"
    
    # iPhone Settings
    "29:2:iphone:58"
    "29:3:iphone:87"
    
    # iPhone Spotlight
    "40:2:iphone:80"
    "40:3:iphone:120"
    
    # iPhone App
    "60:2:iphone:120"
    "60:3:iphone:180"
    
    # iPad Notification
    "20:1:ipad:20"
    "20:2:ipad:40"
    
    # iPad Settings
    "29:1:ipad:29"
    "29:2:ipad:58"
    
    # iPad Spotlight
    "40:1:ipad:40"
    "40:2:ipad:80"
    
    # iPad App
    "76:1:ipad:76"
    "76:2:ipad:152"
    
    # iPad Pro App
    "83.5:2:ipad:167"
    
    # App Store
    "1024:1:ios-marketing:1024"
)

# Contents.json 시작
cat > "$ICON_SET_PATH/Contents.json" << 'EOF'
{
  "images" : [
EOF

FIRST=true

# 각 크기별로 아이콘 생성
for ICON_CONFIG in "${ICON_SIZES[@]}"; do
    IFS=':' read -r SIZE SCALE IDIOM PIXELS <<< "$ICON_CONFIG"
    FILENAME="icon_${PIXELS}x${PIXELS}.png"
    
    echo "🔄 생성 중: ${PIXELS}x${PIXELS} ($SIZE pt @${SCALE}x for $IDIOM)"
    
    # ImageMagick 또는 sips를 사용하여 리사이즈
    if command -v convert &> /dev/null; then
        # ImageMagick 사용
        convert "$SOURCE_IMAGE" -resize "${PIXELS}x${PIXELS}" "$ICON_SET_PATH/$FILENAME"
    else
        # macOS의 sips 사용
        sips -z "$PIXELS" "$PIXELS" "$SOURCE_IMAGE" --out "$ICON_SET_PATH/$FILENAME" > /dev/null 2>&1
    fi
    
    # Contents.json에 항목 추가
    if [ "$FIRST" = false ]; then
        echo "," >> "$ICON_SET_PATH/Contents.json"
    fi
    FIRST=false
    
    if [ "$IDIOM" = "ios-marketing" ]; then
        cat >> "$ICON_SET_PATH/Contents.json" << EOF
    {
      "filename" : "$FILENAME",
      "idiom" : "$IDIOM",
      "scale" : "${SCALE}x",
      "size" : "${SIZE}x${SIZE}"
    }
EOF
    else
        cat >> "$ICON_SET_PATH/Contents.json" << EOF
    {
      "filename" : "$FILENAME",
      "idiom" : "$IDIOM",
      "scale" : "${SCALE}x",
      "size" : "${SIZE}x${SIZE}"
    }
EOF
    fi
done

# Contents.json 마무리
cat >> "$ICON_SET_PATH/Contents.json" << 'EOF'

  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo ""
echo "✅ 앱 아이콘 생성 완료!"
echo "📍 위치: $ICON_SET_PATH"
echo ""
echo "📱 생성된 아이콘:"
ls -la "$ICON_SET_PATH"/*.png | wc -l | xargs echo "   총" && echo "개 파일"
echo ""
echo "🔨 Xcode에서 사용 방법:"
echo "1. Xcode 프로젝트 열기"
echo "2. Assets.xcassets 선택"
echo "3. AppIcon이 자동으로 업데이트됨"
echo "4. Product > Clean Build Folder (Cmd+Shift+K)"
echo "5. Build and Run (Cmd+R)"