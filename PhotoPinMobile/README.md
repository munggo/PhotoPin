# PhotoPin Mobile

Hasselblad X2D II 카메라와 iPhone을 연결하여 GPS 위치 정보를 사진에 자동으로 추가하는 iOS 앱

## 🎯 주요 기능

- **Bluetooth 연결**: Hasselblad 카메라 자동 검색 및 연결
- **WiFi 자동 연결**: NEHotspotConfiguration을 통한 자동 WiFi 전환
- **GPS 트래킹**: 실시간 위치 정보 기록
- **실시간 디버깅**: 연결 상태 모니터링

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

## 🔧 카메라 연결 방법

### 1. 카메라 설정
- 카메라 메뉴 → Wi-Fi → Remote Control 활성화
- 화면에 표시되는 SSID 확인 (예: `X2D-II-100C-003635`)

### 2. 앱에서 연결
1. **Bluetooth 탭**에서 카메라 검색
2. 발견된 Hasselblad 카메라 선택
3. WiFi SSID 입력 (비밀번호 불필요)
4. "자동 연결 시도" 버튼 클릭

### 3. 연결 확인
- WiFi 아이콘이 녹색으로 변경
- "Hasselblad X2D II - 연결됨" 메시지 확인

## 📂 프로젝트 구조

```
PhotoPinMobile/
├── XcodeProject/
│   └── PhotoPin/
│       ├── PhotoPinApp.swift          # 앱 진입점
│       ├── ContentView.swift          # 메인 UI
│       ├── BluetoothCameraManager.swift # BLE/WiFi 연결 관리
│       ├── CameraManager.swift        # 카메라 통신
│       ├── LocationManager.swift      # GPS 트래킹
│       ├── USBCameraManager.swift     # USB 연결 (개발중)
│       └── Info.plist                 # 앱 권한 설정
├── HASSELBLAD_CONNECTION.md          # 카메라 프로토콜 분석
├── WIFI_CONNECTION_GUIDE.md          # WiFi 연결 가이드
└── README.md                          # 이 파일
```

## 🔍 주요 개선사항 (2025-01-07)

### WiFi 연결 개선
- ✅ NEHotspotConfiguration을 통한 자동 연결
- ✅ 다중 IP 주소 시도 (192.168.2.1 우선)
- ✅ 비밀번호 없는 오픈 네트워크 지원
- ✅ 실시간 디버그 로그
- ✅ 향상된 에러 처리

### 지원되는 카메라 IP
- `192.168.2.1` (Hasselblad 기본)
- `192.168.1.1` (대체)
- `192.168.0.1`
- `192.168.4.1`

## 🐛 디버그

앱의 **디버그 탭**에서:
- 실시간 연결 로그 확인
- BLE 특성 값 모니터링
- WiFi 연결 상태 추적
- 에러 메시지 확인

## 📝 문제 해결

### WiFi가 보이지 않을 때
1. 카메라에서 Remote Control 모드 확인
2. 카메라 재시작
3. iPhone WiFi 설정에서 수동 입력

### 연결이 실패할 때
1. 디버그 로그 확인
2. iPhone 프록시 설정 끄기
3. 셀룰러 데이터 일시적으로 끄기

## 📄 라이선스

Private Project

## 🔗 관련 문서

- [HASSELBLAD_CONNECTION.md](HASSELBLAD_CONNECTION.md) - 카메라 통신 프로토콜 상세 분석
- [WIFI_CONNECTION_GUIDE.md](WIFI_CONNECTION_GUIDE.md) - WiFi 연결 상세 가이드

---
*최종 업데이트: 2025-01-07*