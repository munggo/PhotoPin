# Hasselblad X2D II WiFi 연결 가이드

## 📱 개선된 WiFi 연결 방식

### 1. 자동 연결 방식 (BLE 제어)
카메라는 WiFi와 Bluetooth가 항상 켜져있으므로 추가 설정이 필요 없습니다.

#### 연결 과정:
1. **카메라 준비**
   - WiFi: ✅ 이미 켜져있음
   - Bluetooth: ✅ 이미 켜져있음
   - 추가 메뉴 조작: ❌ 필요 없음

2. **앱에서 연결**
   - Bluetooth로 카메라 자동 검색 및 연결
   - BLE 명령으로 WiFi AP 모드 자동 전환
   - iPhone WiFi 목록 새로고침 후 연결

### 2. 다중 IP 주소 시도
카메라 연결 시 다음 IP 주소들을 순차적으로 시도:
- `192.168.2.1` (Hasselblad 가능성 높음)
- `192.168.1.1` (일반적인 카메라 AP)
- `192.168.0.1` (대체 IP)
- `192.168.4.1` (다른 카메라 브랜드)
- `10.0.0.1` (추가 범위)
- `172.20.10.1` (iPhone 핫스팟 범위)

### 3. 디버그 로그 활용
디버그 탭에서 실시간으로 연결 상태를 확인할 수 있습니다:
- BLE 연결 상태
- WiFi 특성 값
- 네트워크 연결 시도 로그
- 에러 메시지

## 🔧 문제 해결

### WiFi가 보이지 않을 때
1. 카메라에서 Remote Control 모드 확인
2. 카메라 재시작
3. iPhone WiFi 설정에서 "기타..." 선택하여 수동 입력

### 연결이 실패할 때
1. 디버그 로그 확인
2. 다른 IP 주소로 시도
3. iPhone 프록시 설정 확인 (꺼져 있어야 함)
4. 셀룰러 데이터 일시적으로 끄기

### BLE 명령이 작동하지 않을 때
- 현재 카메라 펌웨어는 BLE를 통한 WiFi AP 모드 전환을 지원하지 않을 수 있음
- 카메라 메뉴에서 수동으로 Remote Control 활성화 필요

## 📊 연결 프로토콜 분석

### BLE 특성 (서비스 UUID: FFF0)
- `FFF3`: WiFi 제어 (상태: 0x0100 = ON)
- `FFF4`: 카메라 제어
- `FFF5`: 상태 정보
- `FFF7`: 알림

### WiFi AP 정보
- SSID 패턴: `X2D-II-100C-[시리얼번호]`
- 비밀번호: 없음 (Open Network)
- IP 범위: 192.168.2.x

## 🚀 향후 개선 사항

1. **카메라 펌웨어 업데이트 대응**
   - 새로운 BLE 프로토콜 지원
   - 더 나은 WiFi 제어 명령

2. **자동 재연결**
   - 연결 끊김 감지 및 자동 재연결
   - 백그라운드 연결 유지

3. **멀티 카메라 지원**
   - 여러 대의 카메라 동시 관리
   - 카메라별 프로필 저장

## 📝 테스트 체크리스트

- [ ] Bluetooth 스캔 및 카메라 발견
- [ ] BLE 연결 성공
- [ ] WiFi SSID 자동 입력
- [ ] NEHotspotConfiguration 연결
- [ ] 다중 IP 시도
- [ ] TCP 연결 성공
- [ ] 촬영 명령 전송
- [ ] GPS 정보 포함
- [ ] 디버그 로그 확인

## 🔗 참고 자료

- [Apple NEHotspotConfiguration 문서](https://developer.apple.com/documentation/networkextension/nehotspotconfiguration)
- [CoreBluetooth Framework](https://developer.apple.com/documentation/corebluetooth)
- [Network Framework](https://developer.apple.com/documentation/network)

---
*최종 업데이트: 2025-01-07*