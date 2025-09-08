# PhotoPin macOS

Hasselblad X2D II 카메라 사진에 GPS 위치 정보를 자동으로 추가하는 macOS 데스크톱 애플리케이션

## 🎯 주요 기능

- **GPX 파일 지원**: GPS 트랙 로그를 사용한 정밀한 위치 매칭
- **다양한 포맷 지원**: JPG, DNG, RAW (3FR, FFF 등 Hasselblad 포맷 포함)
- **XMP 사이드카**: 원본 파일 보존하며 메타데이터 관리
- **시간대 자동 처리**: UTC/현지 시간 자동 변환
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

### 명령줄 인터페이스
```bash
# XMP 사이드카 모드 (기본, 안전)
PhotoPin --gpx track.gpx --target-dir /path/to/photos

# 파일에 직접 임베드 모드
PhotoPin --gpx track.gpx --target-dir /path/to/photos --mode embed

# 타임존 오프셋 지정
PhotoPin --gpx track.gpx --target-dir /path/to/photos --tz-offset +09:00
```

### 주요 옵션
- `--gpx`: GPX 트랙 파일 경로
- `--target-dir`: 사진 디렉토리 경로
- `--mode`: `sidecar` (기본) 또는 `embed`
- `--tz-offset`: 카메라 시간대 오프셋
- `--max-int`: GPS 포인트 간 최대 보간 시간 (기본 30분)
- `--max-ext`: 트랙 외부 최대 외삽 시간 (기본 2분)

## 📂 프로젝트 구조

```
PhotoPin/
├── Sources/
│   └── main.swift              # 메인 애플리케이션 코드
├── Package.swift               # Swift 패키지 설정
├── Info.plist                  # macOS 앱 메타데이터
├── AppIcon.icns               # macOS 앱 아이콘
├── build_app.sh               # 앱 번들 빌드 스크립트
├── generate_macos_icon.sh     # 아이콘 생성 스크립트
├── geotag.py                  # Python 버전 (레거시)
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

- **원본 백업**: `embed` 모드 사용 시 원본 파일 백업 권장
- **시간 동기화**: 카메라와 GPS 기기의 시간이 정확해야 함
- **GPX 품질**: GPS 트랙의 정확도가 결과에 직접 영향

## 🔗 관련 프로젝트

- [PhotoPin Mobile](../PhotoPinMobile) - iOS 버전 (실시간 GPS 트래킹)
- [geotag.py](./geotag.py) - Python 스크립트 버전

## 📄 라이선스

Private Project

## 🔮 향후 계획

- [ ] GUI 인터페이스 추가
- [ ] 실시간 미리보기 기능
- [ ] 지도 기반 위치 수정
- [ ] 클라우드 동기화
- [ ] 다중 GPX 파일 지원

---
*최종 업데이트: 2025-01-08*