# 📍 PhotoPin

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013.0+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/badge/Version-1.0.0-purple.svg" alt="Version">
</p>

<p align="center">
  <b>Smart Photo Geotagging for macOS</b><br>
  <i>Add GPS location to your photos using GPX tracks</i>
</p>

---

[English](#english) | [한국어](#한국어)

---

## English

## ✨ Features

### 🎯 **Smart Auto Mode**
Automatically selects the optimal processing method based on file format:
- **3FR, FFF** (Hasselblad) → Creates XMP sidecar files
- **JPEG, HEIC** → Embeds metadata directly
- **40+ RAW formats** fully supported

### 🌍 **GPX Timezone Auto-Detection**
- Automatically detects timezone information from GPX files
- Auto-corrects between camera local time and GPS UTC time
- Supports major timezones (Korea +09:00, China +08:00, etc.)

### 📐 **Precise Location Estimation**
- **Interpolation**: Accurately calculates positions between GPS points
- **Extrapolation**: Tags photos outside GPS track with nearest location

### 🎨 **Native macOS App**
- Modern design based on SwiftUI
- Full dark mode support
- Real-time progress display
- Complete internationalization support

## 📸 Supported Formats

| Camera Brand | Supported Formats |
|------------|----------|
| **Common Images** | JPEG, PNG, HEIC, HEIF, TIFF, WebP |
| **Canon** | CR2, CR3, CRW |
| **Nikon** | NEF, NRW |
| **Sony** | ARW, SR2, SRF |
| **Fujifilm** | RAF |
| **Olympus** | ORF |
| **Panasonic** | RW2 |
| **Pentax** | PEF, PTX |
| **Hasselblad** | 3FR, FFF |
| **Phase One** | IIQ |
| **Leica** | RWL, RAW |
| **Others** | DNG, X3F, R3D, ARI, etc. |

## 🚀 Installation

### Prerequisites
- macOS 13.0 (Ventura) or later
- [ExifTool](https://exiftool.org) installation required

```bash
# Install ExifTool via Homebrew
brew install exiftool
```

### Download and Run

1. **Download Latest Release**
   - Download `PhotoPin.app.zip` from [Releases](https://github.com/munggo/PhotoPin/releases)
   - Extract and move to Applications folder

2. **Or Build from Source**
   ```bash
   git clone https://github.com/munggo/PhotoPin.git
   cd PhotoPin
   
   # Build Swift app
   cd GeoTagger
   swift build --configuration release
   
   # Create app bundle
   cd ..
   ./create_app_bundle.sh
   
   # Run app
   open dist/GeoTagger.app
   ```

## 📖 Usage

### 1️⃣ Prepare GPX File
Various ways to record GPS tracks:
- **Smartphone Apps**: Strava, AllTrails, GPS Logger
- **Smartwatches**: Apple Watch, Garmin
- **Dedicated GPS Devices**: Garmin GPS, GPS loggers

### 2️⃣ Run PhotoPin
1. **Select GPX File** - Click "Select File..." button
2. **Select Photo Folder** - Click "Select Folder..." button
3. **Choose Processing Mode** (Auto recommended)
4. Click **"Start Geotagging"**

### 3️⃣ Advanced Settings (Optional)
- **Timezone Offset**: Set if camera uses local time
- **Interpolation Time**: Max time between GPS points (default 30 min)
- **Extrapolation Time**: Max time outside GPS track (default 5 hours)

## 🛠️ Command Line Interface (CLI)

You can also use the Python script directly:

```bash
# Basic usage (Auto mode)
python3 geotag.py --gpx track.gpx --target-dir /path/to/photos

# Sidecar mode (creates XMP files)
python3 geotag.py --gpx track.gpx --target-dir /path/to/photos --mode sidecar

# Set timezone (Korea time)
python3 geotag.py --gpx track.gpx --target-dir /path/to/photos --tz-offset +09:00

# Advanced options
python3 geotag.py --gpx track.gpx \
                  --target-dir /path/to/photos \
                  --mode auto \
                  --tz-offset +09:00 \
                  --max-int 1800 \
                  --max-ext 18000
```

## 💡 Use Cases

### 📷 Travel Photography
```
Problem: Thousands of photos from 2-week Europe trip
Solution: Use daily GPX files to add accurate locations to all photos
Result: Auto-generated map-based albums in Google Photos
```

### 🏔️ Hiking & Trekking
```
Problem: Need exact locations for landscape photos during hikes
Solution: Use GPX tracks from Strava or AllTrails
Result: Record exact shooting points with elevation data
```

### 🎨 Professional Photography
```
Problem: Managing Hasselblad medium format camera RAW files
Solution: Safely add locations to 3FR files with XMP sidecars
Result: Location-based catalog in Lightroom
```

---

## 한국어

## ✨ 주요 기능

### 🎯 **스마트 Auto 모드**
파일 형식에 따라 최적의 처리 방식을 자동으로 선택합니다:
- **3FR, FFF** (Hasselblad) → XMP 사이드카 파일 생성
- **JPEG, HEIC** → 메타데이터 직접 임베드
- **40+ RAW 포맷** 완벽 지원

### 🌍 **GPX 시간대 자동 감지**
- GPX 파일의 시간대 정보 자동 인식
- 카메라 현지 시간과 GPS UTC 시간 자동 보정
- 주요 시간대 지원 (한국 +09:00, 중국 +08:00 등)

### 📐 **정밀한 위치 추정**
- **보간(Interpolation)**: GPS 포인트 사이 위치를 정확하게 계산
- **외삽(Extrapolation)**: GPS 트랙 밖의 사진도 가장 가까운 위치로 태깅

### 🎨 **네이티브 macOS 앱**
- SwiftUI 기반의 모던한 디자인
- 다크모드 완벽 지원
- 실시간 진행률 표시
- 완벽한 국제화 지원

## 📸 지원 포맷

| 카메라 브랜드 | 지원 포맷 |
|------------|----------|
| **일반 이미지** | JPEG, PNG, HEIC, HEIF, TIFF, WebP |
| **Canon** | CR2, CR3, CRW |
| **Nikon** | NEF, NRW |
| **Sony** | ARW, SR2, SRF |
| **Fujifilm** | RAF |
| **Olympus** | ORF |
| **Panasonic** | RW2 |
| **Pentax** | PEF, PTX |
| **Hasselblad** | 3FR, FFF |
| **Phase One** | IIQ |
| **Leica** | RWL, RAW |
| **기타** | DNG, X3F, R3D, ARI 등 |

## 🚀 설치 방법

### 사전 요구사항
- macOS 13.0 (Ventura) 이상
- [ExifTool](https://exiftool.org) 설치 필요

```bash
# Homebrew로 ExifTool 설치
brew install exiftool
```

### 다운로드 및 실행

1. **최신 릴리즈 다운로드**
   - [Releases](https://github.com/munggo/PhotoPin/releases)에서 `PhotoPin.app.zip` 다운로드
   - 압축 해제 후 Applications 폴더로 이동

2. **또는 소스에서 빌드**
   ```bash
   git clone https://github.com/munggo/PhotoPin.git
   cd PhotoPin
   
   # Swift 앱 빌드
   cd GeoTagger
   swift build --configuration release
   
   # 앱 번들 생성
   cd ..
   ./create_app_bundle.sh
   
   # 앱 실행
   open dist/GeoTagger.app
   ```

## 📖 사용법

### 1️⃣ GPX 파일 준비
GPS 트랙을 기록할 수 있는 다양한 방법:
- **스마트폰 앱**: Strava, AllTrails, GPS Logger
- **스마트워치**: Apple Watch, Garmin
- **전용 GPS 기기**: Garmin GPS, GPS 로거

### 2️⃣ PhotoPin 실행
1. **GPX 파일 선택** - "파일 선택..." 버튼 클릭
2. **사진 폴더 선택** - "폴더 선택..." 버튼 클릭
3. **처리 모드 선택** (Auto 권장)
4. **"지오태깅 시작"** 클릭

### 3️⃣ 고급 설정 (선택사항)
- **타임존 오프셋**: 카메라가 현지 시간인 경우 설정
- **보간 시간**: GPS 포인트 사이 최대 시간 (기본 30분)
- **외삽 시간**: GPS 트랙 밖 최대 시간 (기본 5시간)

## 🛠️ 명령줄 인터페이스 (CLI)

Python 스크립트를 직접 사용할 수도 있습니다:

```bash
# 기본 사용법 (Auto 모드)
python3 geotag.py --gpx track.gpx --target-dir /path/to/photos

# Sidecar 모드 (XMP 파일 생성)
python3 geotag.py --gpx track.gpx --target-dir /path/to/photos --mode sidecar

# 타임존 설정 (한국 시간)
python3 geotag.py --gpx track.gpx --target-dir /path/to/photos --tz-offset +09:00

# 고급 옵션
python3 geotag.py --gpx track.gpx \
                  --target-dir /path/to/photos \
                  --mode auto \
                  --tz-offset +09:00 \
                  --max-int 1800 \
                  --max-ext 18000
```

## 💡 사용 시나리오

### 📷 여행 사진 정리
```
문제: 유럽 여행 2주간 촬영한 수천 장의 사진
해결: 매일 기록한 GPX 파일로 모든 사진에 정확한 위치 추가
결과: Google Photos에서 자동으로 지도 기반 앨범 생성
```

### 🏔️ 등산/하이킹 기록
```
문제: 산행 중 촬영한 풍경 사진의 정확한 위치 필요
해결: Strava나 AllTrails의 GPX 트랙 활용
결과: 고도 정보와 함께 정확한 촬영 지점 기록
```

### 🎨 프로 사진 작업
```
문제: Hasselblad 중형 카메라 RAW 파일 관리
해결: 3FR 파일에 XMP 사이드카로 안전하게 위치 추가
결과: Lightroom에서 위치 기반 카탈로그 구성
```

---

## 📁 Project Structure

```
PhotoPin/
├── README.md                 # This document
├── LICENSE                   # MIT License
├── geotag.py                # Core geotagging engine
├── GeoTagger/               # Swift/SwiftUI macOS app
│   ├── Package.swift        # Swift package definition
│   └── Sources/
│       └── GeoTaggerApp.swift  # Main app code
├── create_app_bundle.sh     # App bundle creation script
└── dist/                    # Built app
    └── GeoTagger.app       # Executable macOS app
```

## 🤝 Contributing

Contributions to PhotoPin are welcome!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📜 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [ExifTool](https://exiftool.org) - Powerful metadata tool by Phil Harvey
- [Swift](https://swift.org) - Modern programming language by Apple
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Declarative UI framework

## 📮 Contact

For questions or suggestions, please open an issue on [Issues](https://github.com/munggo/PhotoPin/issues) page.

---

<p align="center">
  Made with ❤️ for photographers who love to travel<br>
  <b>PhotoPin</b> - Pin your memories on the map 📍
</p>