# Hasselblad X2D II XMP 프로토콜 분석

## 📋 현재 상황

### 연결 과정
1. ✅ Phocus 2 앱으로 Bluetooth 연결 성공
2. ✅ WiFi가 활성화되고 "X2D II 100C 003635" SSID 나타남
3. ✅ WiFi 비밀번호: "ejTDqJAS9beL"
4. ✅ PhotoPin이 192.168.2.1에 연결 가능
5. ❌ XMP 파일이 생성되지 않음

### 발견된 문제
- 카메라가 BLE 명령을 에코백만 함 (처리하지 않음)
- GPS 데이터를 전송해도 XMP 파일이 생성되지 않음
- 카메라의 정확한 프로토콜을 모름

## 🔍 XMP 파일 분석

### Hasselblad XMP 파일 구조
```xml
<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description rdf:about=""
      xmlns:exif="http://ns.adobe.com/exif/1.0/"
      xmlns:tiff="http://ns.adobe.com/tiff/1.0/"
      xmlns:xmp="http://ns.adobe.com/xap/1.0/"
      xmlns:aux="http://ns.adobe.com/exif/1.0/aux/"
      xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/"
      xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/">
      
      <!-- GPS 데이터 -->
      <exif:GPSLatitude>37.5665</exif:GPSLatitude>
      <exif:GPSLatitudeRef>N</exif:GPSLatitudeRef>
      <exif:GPSLongitude>126.9780</exif:GPSLongitude>
      <exif:GPSLongitudeRef>E</exif:GPSLongitudeRef>
      <exif:GPSAltitude>50</exif:GPSAltitude>
      <exif:GPSAltitudeRef>0</exif:GPSAltitudeRef>
      <exif:GPSTimeStamp>2024-12-01T10:30:00Z</exif:GPSTimeStamp>
      
      <!-- 카메라 정보 -->
      <tiff:Make>Hasselblad</tiff:Make>
      <tiff:Model>X2D II 100C</tiff:Model>
      <exif:SerialNumber>003635</exif:SerialNumber>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>
```

## 🔧 가능한 프로토콜

### 1. HTTP REST API
카메라가 HTTP 서버를 실행하고 REST API를 제공할 가능성:
```
POST http://192.168.2.1/api/location
Content-Type: application/json

{
  "latitude": 37.5665,
  "longitude": 126.9780,
  "altitude": 50,
  "timestamp": "2024-12-01T10:30:00Z"
}
```

### 2. PTP/IP (Picture Transfer Protocol over IP)
표준 카메라 프로토콜 - 포트 15740:
- InitiateSession
- SetDevicePropValue (GPS 속성 설정)
- GetObjectInfo (파일 정보)

### 3. 실시간 스트리밍
카메라가 실시간으로 GPS 데이터를 수신하여 촬영 시 적용:
- TCP/UDP 소켓 연결
- 지속적인 위치 데이터 스트림

### 4. 파일 시스템 직접 접근
FTP/WebDAV를 통한 XMP 파일 직접 업로드:
```
PUT ftp://192.168.2.1/DCIM/100HASBL/IMG_0001.xmp
```

## 📡 테스트 계획

### 1단계: 포트 스캔
```bash
# 카메라 연결 후 실행
python3 test_camera_connection.py
```

### 2단계: HTTP 엔드포인트 탐색
```bash
# 다양한 엔드포인트 테스트
curl -X GET http://192.168.2.1/
curl -X GET http://192.168.2.1/api
curl -X GET http://192.168.2.1/status
curl -X POST http://192.168.2.1/gps -H "Content-Type: application/json" -d '{"lat":37.5,"lng":127.0}'
```

### 3단계: 네트워크 트래픽 캡처
```bash
# Phocus 사용 중 패킷 캡처
sudo tcpdump -i en0 host 192.168.2.1 -w phocus_capture.pcap

# 분석
tcpdump -r phocus_capture.pcap -A | grep -E "GPS|location|XMP"
```

### 4단계: mDNS/Bonjour 서비스 발견
```bash
# 카메라가 광고하는 서비스 확인
dns-sd -B _http._tcp
dns-sd -B _ptp._tcp
```

## 🎯 다음 단계

1. **네트워크 분석 도구 사용**
   - Wireshark로 Phocus 트래픽 캡처
   - Charles Proxy로 HTTP 트래픽 분석

2. **리버스 엔지니어링**
   - Phocus 앱 바이너리 분석 (Hopper/IDA)
   - 문자열 검색으로 API 엔드포인트 찾기

3. **실험적 접근**
   - 모든 가능한 포트에 GPS 데이터 전송
   - 다양한 형식 시도 (JSON, XML, 바이너리)

4. **커뮤니티 리소스**
   - Hasselblad 개발자 포럼
   - PTP/IP 구현 라이브러리
   - 오픈소스 카메라 제어 프로젝트

## 💡 중요 인사이트

1. **Phocus는 비밀번호를 자동 처리**
   - 앱 내부에 하드코딩되어 있을 가능성
   - BLE를 통해 인증 토큰을 받을 수도 있음

2. **최대 5대 페어링 제한**
   - 카메라가 장치를 기억하고 관리
   - 인증 메커니즘이 있을 가능성

3. **XMP 파일이 생성되지 않음**
   - 단순 연결만으로는 부족
   - 특정 프로토콜/명령 필요
   - 촬영 트리거와 동기화 필요할 수 있음

## 📝 테스트 로그

### 2024-12-XX 테스트 결과
- [ ] 포트 스캔 결과: 
- [ ] HTTP 엔드포인트 발견:
- [ ] PTP/IP 연결 시도:
- [ ] 패킷 캡처 분석:

## 🔗 참고 자료

- [PTP/IP 프로토콜 문서](https://en.wikipedia.org/wiki/Picture_Transfer_Protocol)
- [XMP 사양](https://www.adobe.com/devnet/xmp.html)
- [Hasselblad SDK](https://www.hasselblad.com/developers/) (존재 여부 확인 필요)