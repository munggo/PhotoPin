# PhotoPin macOS

Hasselblad X2D II 카메라 사진에 GPS 위치 정보를 자동으로 추가하는 macOS 데스크톱 애플리케이션

## 🎯 주요 기능

- **GPX 파일 지원**: GPS 트랙 로그를 사용한 정밀한 위치 매칭
- **다양한 포맷 지원**: JPG, DNG, RAW (3FR, FFF 등 Hasselblad 포맷 포함)
- **XMP 전용 모드**: 원본 파일을 절대 수정하지 않고 안전하게 처리
- **스마트 스킵**: 이미 XMP가 있는 파일은 자동으로 건너뛰기
- **중복 파일명 처리**: 동일 파일명의 다른 확장자(jpg, raw 등)는 하나의 XMP로 관리
- **시간대 자동 감지**: GPX 파일에서 시간대 정보 자동 추출
- **배치 처리**: 여러 파일 동시 처리 지원

## 📱 요구사항

- macOS 13.0 (Ventura) 이상
- Swift 5.9 이상
- ExifTool 설치 필요

## 🚀 설치 및 빌드

### ExifTool 설치
```bash
# Homebrew를 사용한 설치
brew install exiftool
```

### 앱 빌드
```bash
# 릴리즈 빌드
swift build --configuration release

# 앱 번들 생성 (아이콘 포함)
./build_app.sh

# 실행
open ../dist/PhotoPin.app
```

## 🎨 앱 아이콘

PhotoPin은 커스텀 앱 아이콘을 포함합니다:
- `AppIcon.icns`: macOS 네이티브 아이콘 포맷
- 16x16부터 1024x1024까지 모든 해상도 지원
- Retina 디스플레이 최적화

### 아이콘 재생성
```bash
# 원본 이미지가 있는 경우 아이콘 재생성
./generate_macos_icon.sh
```

## 🔧 사용 방법

### GUI 앱 실행
```bash
# 빌드 후 실행
open ../dist/PhotoPin.app

# 또는 개발 모드에서
swift run
```

### 작업 프로세스
1. GPX 트랙 파일 선택
2. 사진 폴더 선택
3. 필요 시 타임존 오프셋 설정 (자동 감지됨)
4. '지오태깅 시작' 버튼 클릭
5. XMP 파일 생성 완료

### 주요 특징
- **안전 모드**: 항상 XMP 사이드카만 생성 (원본 파일 보호)
- **스마트 처리**: 이미 처리된 파일은 자동 스킵하여 효율성 증대
- **타임존 자동 감지**: GPX 파일에서 시간대 정보 자동 추출
- **보간 시간**: GPS 포인트 간 최대 30분 (조정 가능)
- **외삽 시간**: 트랙 외부 최대 5시간 (조정 가능)
- **실시간 상태 표시**: 처리 전 스킵될 파일 개수 미리 확인

## 📂 프로젝트 구조

```
PhotoPin/
├── Sources/
│   └── PhotoPinApp.swift      # 메인 SwiftUI 앱 및 뷰모델
├── Package.swift               # Swift 패키지 설정
├── Info.plist                  # macOS 앱 메타데이터
├── AppIcon.icns               # macOS 앱 아이콘
├── build_app.sh               # 앱 번들 빌드 스크립트
├── generate_macos_icon.sh     # 아이콘 생성 스크립트
└── README.md                  # 이 파일
```

## 🔍 지원 파일 형식

### 일반 이미지
- JPG, JPEG
- PNG
- HEIC, HEIF

### RAW 포맷
- DNG (Adobe)
- ARW (Sony)
- CR2, CR3 (Canon)
- NEF (Nikon)
- RAF (Fujifilm)
- ORF (Olympus)
- RW2 (Panasonic)

### Hasselblad 전용
- 3FR (Hasselblad RAW)
- FFF (Hasselblad Phocus)
- TIF, TIFF

## ⚠️ 주의사항

- **안전 모드**: 항상 XMP 사이드카만 생성하여 원본 파일을 보호합니다
- **중복 파일명**: 동일한 파일명의 다른 확장자는 하나의 XMP로 관리됩니다
- **시간 동기화**: 카메라와 GPS 기기의 시간이 정확해야 함
- **GPX 품질**: GPS 트랙의 정확도가 결과에 직접 영향

## 🔗 관련 프로젝트

- [PhotoPin Mobile](../PhotoPinMobile) - iOS 버전 (실시간 GPS 트래킹)

## 📄 라이선스

Private Project

## 🔮 향후 계획

- [✓] GUI 인터페이스 (SwiftUI로 구현 완료)
- [✓] XMP 전용 모드로 안전성 강화
- [✓] 이미 처리된 파일 스킵 기능
- [ ] 실시간 미리보기 기능
- [ ] 지도 기반 위치 수정
- [ ] 클라우드 동기화
- [ ] 다중 GPX 파일 지원

---
*최종 업데이트: 2025-01-13*