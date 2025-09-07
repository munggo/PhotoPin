# Hasselblad X2D II 카메라 연결 프로토콜 분석

## 📱 프로젝트 개요
PhotoPin Mobile - Hasselblad X2D II 카메라와 iPhone을 연결하여 GPS 위치 정보를 사진에 자동으로 추가하는 iOS 앱

## 🔍 현재까지 발견한 내용

### 1. Bluetooth 연결 ✅ 성공
- **카메라 식별 정보**
  - 이름: `X2D II 100C 003635`
  - UUID: `A3C4E380-43DB-D33C-7887-13C55C971A04`
  - 제조사 ID: `0xAA08` (Hasselblad)
  - 서비스: `FFF0`, `Battery`, `Human Interface Device`

### 2. BLE 서비스 및 특성
- **FFF0 서비스** (Hasselblad 커스텀 서비스)
  - `FFF3` (읽기/쓰기): Wi-Fi 제어 특성
  - `FFF4` (읽기/쓰기): 카메라 제어 특성
  - `FFF5` (읽기): 상태 특성
  - `FFF7` (알림): 알림 특성

### 3. 통신 프로토콜 분석

#### Wi-Fi 상태 코드 (FFF3)
```
0x0100    = Wi-Fi ON (클라이언트 모드)
0x0000    = Wi-Fi OFF
0x020001  = Wi-Fi 활성화 명령
0x040100  = AP 모드 (추정)
```

#### 시도한 명령들
```
0x020001  = Wi-Fi ON 명령 → 응답: 에코 반환
0x030001  = Wi-Fi 정보 요청 → 응답: 에코 반환
0x040100  = AP 모드 활성화 → 응답: 없음
0x0A0001  = 원격 제어 모드 → 응답: 없음
```

### 4. 카메라 설정

#### 카메라 사전 설정
1. **Bluetooth**: ✅ 항상 켜져있음 (카메라 자체 기능)
2. **Wi-Fi**: ✅ 항상 켜져있음 (카메라 자체 기능)
3. **추가 메뉴 조작**: ❌ 필요 없음

#### BLE를 통한 제어
- 카메라는 이미 WiFi와 Bluetooth가 활성화되어 있음
- BLE 명령으로 WiFi AP 모드 전환 가능
- iPhone에서 WiFi 목록 새로고침 필요

### 5. Phocus 앱 동작 방식 (추정)
1. Bluetooth로 카메라 연결
2. Wi-Fi 상태 확인 및 AP 모드 전환
3. iPhone이 카메라 Wi-Fi AP에 연결
4. TCP/IP 통신으로 카메라 제어

### 6. 추가 조사 필요 사항
- [ ] 카메라 메뉴에서 수동으로 Wi-Fi AP 모드 활성화 방법
- [ ] Phocus 앱 패킷 캡처 및 분석
- [ ] 다른 BLE 특성 값 읽기/쓰기 시도
- [ ] 카메라 펌웨어 버전별 차이점 확인

## 📊 테스트 로그 요약

### Bluetooth 스캔 결과
```
✅ Hasselblad X2D II 카메라 발견!
카메라 이름: X2D II 100C 003635
서비스: [FFF0, Battery, Human Interface Device]
제조사 ID: aa08
```

### 특성 응답 패턴
```
FFF3 값: 0x0100 → Wi-Fi ON 상태
FFF4 값: 0x030001 → 명령 에코
FFF5 값: 0x030001 → 상태 에코
FFF7 값: 0x0100 → 알림
```

### 네트워크 연결 시도
```
🔗 카메라 연결 시도: 192.168.1.1:80
❌ 503 에러: unreachable through proxy
원인: iPhone이 카메라 Wi-Fi에 연결되지 않음
```

## 🎯 다음 단계

### 옵션 1: 카메라 수동 설정
1. 카메라 메뉴에서 Wi-Fi 설정 확인
2. "Remote Control" 또는 "Phocus Mobile" 모드 활성화
3. 카메라 화면에 표시되는 Wi-Fi 정보 확인

### 옵션 2: 리버스 엔지니어링
1. Phocus 앱 사용 시 Bluetooth 패킷 캡처
2. Wi-Fi 활성화 시퀀스 분석
3. 정확한 명령 코드 파악

### 옵션 3: 대체 연결 방식
1. USB-C 직접 연결 방식 구현
2. 카메라 SD 카드 직접 접근
3. XMP 사이드카 파일 생성 후 별도 동기화

## 🔧 기술 스택
- **iOS**: SwiftUI, CoreBluetooth, Network.framework
- **언어**: Swift 5
- **최소 iOS**: 16.0
- **Xcode**: 15.0+

## 📝 참고사항
- Hasselblad X2D II 펌웨어 버전에 따라 프로토콜이 다를 수 있음
- Phocus 앱은 추가적인 인증 과정이 있을 가능성
- 카메라 Wi-Fi는 5GHz 대역을 사용할 수 있음 (iPhone 호환성 확인 필요)

## 🚀 현재 구현된 기능
1. ✅ Bluetooth 장치 스캔 및 Hasselblad 카메라 자동 감지
2. ✅ BLE 연결 및 서비스 검색
3. ✅ Wi-Fi 상태 확인
4. ⚠️ Wi-Fi AP 모드 전환 (미완성)
5. ❌ TCP/IP 통신을 통한 카메라 제어
6. ❌ GPS 정보 전송 및 사진 메타데이터 업데이트

---
*마지막 업데이트: 2025-01-06*