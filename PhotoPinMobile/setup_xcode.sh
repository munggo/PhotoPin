#!/bin/bash

# PhotoPin Xcode 프로젝트 설정 스크립트
# Hotspot Configuration과 Network Extensions 자동 설정

echo "📱 PhotoPin Xcode 프로젝트 설정 시작..."

PROJECT_DIR="/Users/munkyo/works/ai-code/photo/PhotoPinMobile/XcodeProject"
PROJECT_FILE="$PROJECT_DIR/PhotoPin.xcodeproj/project.pbxproj"

# 1. xcconfig 파일 적용
echo "1️⃣ Build Configuration 설정..."
if [ -f "$PROJECT_DIR/PhotoPin.xcconfig" ]; then
    echo "✅ PhotoPin.xcconfig 파일 확인됨"
else
    echo "❌ PhotoPin.xcconfig 파일이 없습니다"
fi

# 2. Entitlements 확인
echo "2️⃣ Entitlements 파일 확인..."
if [ -f "$PROJECT_DIR/PhotoPin/PhotoPin.entitlements" ]; then
    echo "✅ PhotoPin.entitlements 파일 확인됨"
else
    echo "❌ PhotoPin.entitlements 파일이 없습니다"
fi

# 3. Info.plist 권한 확인
echo "3️⃣ Info.plist 권한 확인..."
if grep -q "com.apple.developer.networking.HotspotConfiguration" "$PROJECT_DIR/PhotoPin/Info.plist"; then
    echo "✅ Hotspot Configuration 권한 설정됨"
else
    echo "⚠️ Hotspot Configuration 권한 추가 필요"
fi

# 4. Xcode 프로젝트 열기
echo "4️⃣ Xcode 프로젝트 열기..."
open "$PROJECT_DIR/PhotoPin.xcodeproj"

echo ""
echo "📋 Xcode에서 수동으로 확인할 사항:"
echo "   1. PhotoPin 타겟 선택"
echo "   2. Signing & Capabilities 탭"
echo "   3. '+ Capability' 버튼 클릭"
echo "   4. 'Hotspot Configuration' 추가"
echo "   5. Build Settings → Code Signing Entitlements"
echo "      값: PhotoPin/PhotoPin.entitlements"
echo ""
echo "✅ 설정 완료 후 앱을 다시 빌드하세요!"