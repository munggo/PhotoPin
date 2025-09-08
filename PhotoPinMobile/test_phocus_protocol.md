# 📱 Phocus 프로토콜 테스트 가이드

## 🎯 목표
Phocus 앱이 사용하는 정확한 BLE 프로토콜을 파악하기

## 📋 테스트 절차

### 1단계: 준비
1. 카메라 전원 켜기
2. iPhone Bluetooth 설정에서 X2D 연결 해제
3. iPhone WiFi 설정 확인 (X2D 네트워크 없어야 함)

### 2단계: BLE 패킷 캡처 시작
터미널에서 실행:
```bash
cd /Users/munkyo/works/ai-code/photo/PhotoPinMobile
./capture_phocus_protocol.sh
```

### 3단계: Phocus 앱 테스트
1. Phocus 2 앱 실행
2. 카메라 연결
3. WiFi 활성화 확인
4. **iPhone 설정 > WiFi에서 SSID 확인**
5. SSID가 나타나면 앱 종료

### 4단계: 우리 앱 테스트 (비교용)
1. PhotoPin 앱 실행
2. 카메라 연결 시도
3. 로그 확인

## 🔍 확인 사항

### WiFi SSID가 나타났을 때:
- [ ] 정확한 SSID 이름
- [ ] 비밀번호 필요 여부
- [ ] IP 주소 대역 (192.168.X.X)

### 캡처된 로그 분석:
- FFF3에 전송된 실제 명령
- 명령 순서와 타이밍
- FFF7 notify 데이터

## 💡 문제 해결

### 현재 상황:
- ✅ BLE 연결 성공
- ✅ AP 모드 전환 (0x040100)
- ❌ WiFi AP 브로드캐스트 안됨
- ❌ 명령이 에코백됨 (처리 안됨)

### 가능한 원인:
1. **인증 필요**: 특별한 핸드셰이크나 키 교환
2. **다른 특성 사용**: FFF7이나 다른 서비스 활용
3. **명령 형식 차이**: 헤더나 체크섬 필요
4. **타이밍 문제**: 명령 사이 더 긴 대기 시간

## 📝 다음 단계

1. **Phocus 패킷 정밀 분석**
   - writeWithResponse vs writeWithoutResponse
   - 명령 전후 읽기 패턴
   - FFF7 notify 데이터 확인

2. **대안 시도**
   - FFF7에 notify 설정 후 명령 전송
   - Battery/HID 서비스 초기화
   - 다른 명령 형식 (길이 포함, CRC 등)

3. **수동 WiFi 연결**
   - Phocus로 WiFi 활성화
   - 우리 앱에서 직접 WiFi 연결만 시도