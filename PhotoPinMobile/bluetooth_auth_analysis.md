# Hasselblad X2D II Bluetooth 인증 분석

## 현재 문제
- 카메라가 BLE 명령을 처리하지 않고 에코백만 함
- 예: `0x040100` 전송 → `0x040100` 응답 (처리되지 않음)

## 가능한 인증 메커니즘

### 1. 페어링 기반 인증
- 최대 5대 기기만 페어링 가능
- 6번째 기기는 첫 번째를 대체
- **Phocus는 페어링 과정을 자동 처리**

### 2. Challenge-Response 인증
```
1. 앱 → 카메라: 인증 요청
2. 카메라 → 앱: Challenge 값
3. 앱 → 카메라: Response (암호화된 응답)
4. 카메라 → 앱: 인증 성공
```

### 3. 세션 키 교환
- Diffie-Hellman 키 교환
- 또는 사전 공유 키 (PSK) 사용

## 테스트할 인증 시퀀스

### 시퀀스 1: 초기화 핸드셰이크
```swift
// 1. 인증 시작
writeToFFF3(Data([0x01, 0x00]))  // AUTH_START

// 2. 기기 ID 전송
let deviceID = UUID().uuidString.data(using: .utf8)!
writeToFFF3(Data([0x02]) + deviceID)  // DEVICE_ID

// 3. 인증 확인
readFromFFF3()  // AUTH_RESPONSE
```

### 시퀀스 2: 제조사 특정 인증
```swift
// Hasselblad 제조사 ID 사용
let mfgID = Data([0xAA, 0x08])  // 로그에서 발견된 제조사 ID
writeToFFF3(Data([0x00, 0x01]) + mfgID)
```

### 시퀀스 3: 표준 BLE 페어링
```swift
// iOS 시스템 페어링 요청
peripheral.delegate = self
// didUpdateNotificationState에서 페어링 처리
```

## WiFi 비밀번호와의 연관성

WiFi 비밀번호 "ejTDqJAS9beL"이 BLE 인증에도 사용될 가능성:
- Base64 인코딩/디코딩
- HMAC 키로 사용
- Challenge-Response의 시드

## 다음 단계

1. **Phocus 로그 캡처 강화**
   - 연결 초기 단계 집중 모니터링
   - FFF3에 처음 쓰는 값 확인

2. **시험적 인증 구현**
   - 위 시퀀스들을 순차적으로 테스트
   - 응답 패턴 분석

3. **리버스 엔지니어링**
   - Phocus 앱 바이너리 분석
   - 인증 관련 문자열 검색