# PhotoPin Mobile

Hasselblad X2D II 카메라와 iPhone을 연결하여 GPS 위치 정보를 사진에 자동으로 추가하는 iOS 앱

## 🎯 주요 기능

- **Bluetooth 연결**: Hasselblad 카메라 자동 검색 및 연결
- **WiFi 활성화**: BLE를 통한 카메라 WiFi 자동 활성화 시도
- **GPS 트래킹**: 실시간 위치 정보 수집 및 전송
- **위치 데이터 전송**: HTTP/TCP/PTP 프로토콜 자동 탐색
- **실시간 디버깅**: 상세한 연결 상태 및 로그 모니터링

## 📱 요구사항

- iOS 16.0 이상
- Xcode 15.0 이상
- 실제 iPhone 기기 (Bluetooth/WiFi 테스트 필요)

## 🚀 빌드 및 실행

```bash
# 프로젝트 디렉토리로 이동
cd XcodeProject

# Xcode 프로젝트 열기
open PhotoPin.xcodeproj
```

### Xcode에서 실행
1. 실제 iPhone 연결
2. 타겟 디바이스 선택
3. Run (Cmd+R)

## 🎨 앱 아이콘

PhotoPin은 커스텀 앱 아이콘을 포함합니다:
- iOS와 iPadOS 모든 크기 지원 (20x20 ~ 1024x1024)
- Assets.xcassets에 자동 포함
- Retina 디스플레이 최적화

### 아이콘 재생성
```bash
# iOS 앱 아이콘 재생성
./generate_app_icons.sh
```

## 🔧 카메라 연결 방법

### 권장 방법: Phocus 2 + PhotoPin 조합

#### 1단계: Phocus 2로 WiFi 활성화
1. Phocus 2 앱 실행
2. 카메라와 Bluetooth 연결
3. WiFi가 자동 활성화될 때까지 대기 (1-3초)

#### 2단계: iPhone WiFi 설정
1. 설정 → Wi-Fi 열기
2. "X2D II 100C 003635" 네트워크 선택
3. 비밀번호: `ejTDqJAS9beL` 입력

#### 3단계: PhotoPin 사용
1. PhotoPin 앱 실행
2. GPS 탭 → "GPS 시작" 버튼
3. "카메라로 전송" 버튼 클릭

### 대안: PhotoPin 단독 사용 (제한적)
1. **카메라 탭**에서 Bluetooth 연결
2. WiFi 활성화 시도 (현재 인증 문제로 제한적)
3. 수동으로 WiFi 연결 필요

## 📂 프로젝트 구조

```
PhotoPinMobile/
├── XcodeProject/
│   └── PhotoPin/
│       ├── PhotoPinApp.swift          # 앱 진입점
│       ├── ContentView.swift          # 메인 UI
│       ├── BluetoothCameraManager.swift # BLE/WiFi 연결 관리
│       ├── CameraManager.swift        # WiFi 직접 연결
│       ├── LocationManager.swift      # GPS 트래킹
│       ├── LocationService.swift      # 위치 데이터 전송
│       ├── USBCameraManager.swift     # USB 연결 (개발중)
│       └── Info.plist                 # 앱 권한 설정
├── generate_app_icons.sh              # iOS 앱 아이콘 생성 스크립트
├── analyze_camera_protocol.py         # 프로토콜 분석 도구
├── test_camera_connection.py          # 연결 테스트 도구
├── bluetooth_auth_analysis.md         # BLE 인증 분석
├── xmp_protocol_analysis.md           # XMP 프로토콜 분석
├── HASSELBLAD_CONNECTION.md          # 카메라 프로토콜 분석
├── WIFI_CONNECTION_GUIDE.md          # WiFi 연결 가이드
└── README.md                          # 이 파일
```

## 🔍 주요 개선사항 (2025-01-07)

### ✅ 완료된 기능
- Bluetooth LE를 통한 카메라 자동 검색 및 연결
- 서비스 FFF0과 특성(FFF3, FFF4, FFF5, FFF7) 탐색
- LocationService를 통한 다중 프로토콜 지원
- 실시간 디버그 로그 및 상태 모니터링
- GPS 위치 수집 및 전송 준비

### ⚠️ 알려진 제한사항
- **BLE 인증 문제**: Hasselblad 독자 프로토콜로 인한 명령 처리 실패
- **WiFi 자동 활성화 불가**: Phocus 앱만 인증 키 보유
- **최대 5대 페어링 제한**: 6번째 기기는 첫 번째 대체
- **NEHotspotConfiguration 오류**: iOS 시스템 레벨 간헐적 실패

### 📡 네트워크 정보
- **WiFi SSID**: `X2D II 100C 003635` (시리얼 번호 포함)
- **비밀번호**: `ejTDqJAS9beL`
- **카메라 IP**: `192.168.2.1`
- **지원 포트**: 80 (HTTP), 15740 (PTP/IP)

## 🐛 디버그

앱의 **디버그 탭**에서:
- 실시간 연결 로그 확인
- BLE 특성 값 모니터링
- WiFi 연결 상태 추적
- 에러 메시지 확인

## 📝 문제 해결

### WiFi가 활성화되지 않을 때
- **원인**: BLE 인증 프로토콜 미구현
- **해결**: Phocus 2 앱으로 먼저 연결 후 PhotoPin 사용

### NEHotspotConfiguration 오류
- **원인**: iOS 시스템 권한 또는 서비스 오류
- **해결**: iPhone 설정에서 수동으로 WiFi 연결

### GPS 데이터가 전송되지 않음
- **원인**: 카메라와 WiFi 미연결
- **해결**: 
  1. WiFi 연결 상태 확인
  2. ping 192.168.2.1 테스트
  3. LocationService 연결 타입 확인

### BLE 명령이 에코백만 되는 경우
- **원인**: 인증되지 않은 상태
- **현재 상태**: 연구 중 (Phocus 프로토콜 분석 필요)

## 📄 라이선스

Private Project

## 🔮 향후 계획

1. **BLE 인증 프로토콜 구현**
   - Phocus 앱 리버스 엔지니어링
   - Challenge-Response 메커니즘 분석
   
2. **XMP 파일 직접 생성**
   - 카메라가 인식하는 메타데이터 형식 연구
   - EXIF/XMP 표준 준수

3. **PTP/IP 완전 구현**
   - 표준 카메라 제어 프로토콜
   - 원격 촬영 기능 추가

## 🔗 관련 문서

- [HASSELBLAD_CONNECTION.md](HASSELBLAD_CONNECTION.md) - 카메라 통신 프로토콜 상세 분석
- [WIFI_CONNECTION_GUIDE.md](WIFI_CONNECTION_GUIDE.md) - WiFi 연결 상세 가이드  
- [bluetooth_auth_analysis.md](bluetooth_auth_analysis.md) - BLE 인증 메커니즘 분석
- [xmp_protocol_analysis.md](xmp_protocol_analysis.md) - XMP 파일 생성 프로토콜

---
*최종 업데이트: 2025-01-08 (아이콘 추가)*