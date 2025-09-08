#!/bin/bash

# Xcode 프로젝트에 LocationService.swift 추가하는 스크립트

echo "📱 LocationService.swift를 Xcode 프로젝트에 추가합니다..."

# 프로젝트 경로
PROJECT_PATH="/Users/munkyo/works/ai-code/photo/PhotoPinMobile/XcodeProject/PhotoPin.xcodeproj"
PROJECT_FILE="$PROJECT_PATH/project.pbxproj"

# 백업 생성
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"
echo "✅ 백업 생성: $PROJECT_FILE.backup"

# UUID 생성 함수
generate_uuid() {
    uuidgen | tr -d '-' | tr '[:lower:]' '[:upper:]' | cut -c1-24
}

# LocationService.swift를 위한 UUID 생성
FILE_REF_UUID=$(generate_uuid)
BUILD_FILE_UUID=$(generate_uuid)

echo "📝 생성된 UUID:"
echo "  - File Reference: $FILE_REF_UUID"
echo "  - Build File: $BUILD_FILE_UUID"

# 프로젝트 파일 읽기
PROJECT_CONTENT=$(cat "$PROJECT_FILE")

# LocationManager.swift 참조 찾기 (기준점으로 사용)
LOCATION_MANAGER_REF=$(grep -o '[A-Z0-9]\{24\} /\* LocationManager.swift \*/' "$PROJECT_FILE" | head -1 | cut -d' ' -f1)

if [ -z "$LOCATION_MANAGER_REF" ]; then
    echo "❌ LocationManager.swift 참조를 찾을 수 없습니다."
    exit 1
fi

echo "📍 LocationManager.swift 참조 발견: $LOCATION_MANAGER_REF"

# 1. PBXFileReference 섹션에 추가
# LocationManager.swift 라인 다음에 LocationService.swift 추가
sed -i '' "/$LOCATION_MANAGER_REF \/\* LocationManager.swift \*\//a\\
		$FILE_REF_UUID /* LocationService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LocationService.swift; sourceTree = \"<group>\"; };
" "$PROJECT_FILE"

# 2. PBXGroup (소스 파일 그룹)에 추가
# LocationManager.swift가 있는 그룹에 LocationService.swift 추가
sed -i '' "/$LOCATION_MANAGER_REF \/\* LocationManager.swift \*\//a\\
				$FILE_REF_UUID /* LocationService.swift */,
" "$PROJECT_FILE"

# 3. PBXSourcesBuildPhase에 추가
# LocationManager.swift의 빌드 파일 참조 찾기
LOCATION_MANAGER_BUILD=$(grep -B1 "$LOCATION_MANAGER_REF \/\* LocationManager.swift in Sources \*/" "$PROJECT_FILE" | head -1 | grep -o '^[[:space:]]*[A-Z0-9]\{24\}' | tr -d '[:space:]')

if [ ! -z "$LOCATION_MANAGER_BUILD" ]; then
    # LocationManager 빌드 참조 다음에 LocationService 빌드 참조 추가
    sed -i '' "/$LOCATION_MANAGER_BUILD \/\* LocationManager.swift in Sources \*\//a\\
				$BUILD_FILE_UUID /* LocationService.swift in Sources */,
" "$PROJECT_FILE"
    
    # PBXBuildFile 섹션에 추가
    sed -i '' "/\/\* Begin PBXBuildFile section \*\//a\\
		$BUILD_FILE_UUID /* LocationService.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF_UUID /* LocationService.swift */; };
" "$PROJECT_FILE"
fi

echo "✅ LocationService.swift가 Xcode 프로젝트에 추가되었습니다."
echo ""
echo "📌 다음 단계:"
echo "1. Xcode를 완전히 종료"
echo "2. Xcode 다시 열기"
echo "3. Clean Build Folder (Cmd+Shift+K)"
echo "4. Build (Cmd+B)"