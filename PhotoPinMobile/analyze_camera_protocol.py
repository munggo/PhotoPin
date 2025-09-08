#!/usr/bin/env python3
"""
Hasselblad X2D II 카메라 프로토콜 분석 스크립트
카메라가 사용하는 네트워크 프로토콜과 API 엔드포인트를 찾습니다.
"""

import socket
import requests
import time
import json
from typing import Dict, List, Tuple
import subprocess
import sys

# 카메라 IP
CAMERA_IP = "192.168.2.1"

def scan_ports(host: str, start_port: int = 1, end_port: int = 10000) -> List[int]:
    """열린 포트를 스캔합니다"""
    print(f"🔍 {host}의 포트 스캔 중... (1-10000)")
    open_ports = []
    
    # 일반적인 카메라/PTP 포트부터 확인
    common_ports = [
        80,    # HTTP
        443,   # HTTPS
        8080,  # Alternative HTTP
        8443,  # Alternative HTTPS
        15740, # PTP/IP
        5353,  # mDNS
        1900,  # UPnP
        9000,  # 일부 카메라 제어
        554,   # RTSP
        21,    # FTP
        22,    # SSH
        23,    # Telnet
    ]
    
    print("📌 일반적인 포트 확인 중...")
    for port in common_ports:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.5)
        result = sock.connect_ex((host, port))
        if result == 0:
            print(f"  ✅ 포트 {port} 열림")
            open_ports.append(port)
        sock.close()
    
    # 나머지 포트 스캔 (시간이 걸리므로 선택적)
    if len(sys.argv) > 1 and sys.argv[1] == "--full":
        print("\n🔍 전체 포트 스캔 중...")
        for port in range(start_port, end_port + 1):
            if port not in common_ports:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(0.1)
                result = sock.connect_ex((host, port))
                if result == 0:
                    print(f"  ✅ 포트 {port} 열림")
                    open_ports.append(port)
                sock.close()
    
    return sorted(open_ports)

def test_http_endpoints(host: str, port: int = 80) -> Dict[str, any]:
    """HTTP API 엔드포인트를 테스트합니다"""
    print(f"\n🌐 HTTP 엔드포인트 테스트 (포트 {port})")
    
    base_url = f"http://{host}:{port}"
    endpoints = [
        "/",
        "/api",
        "/api/v1",
        "/api/v2",
        "/status",
        "/info",
        "/device-info",
        "/camera",
        "/camera/info",
        "/camera/status",
        "/gps",
        "/location",
        "/geotag",
        "/xmp",
        "/metadata",
        "/capture",
        "/shoot",
        "/trigger",
        "/settings",
        "/config",
        "/control",
        "/ptp",
        "/ptp/info",
        "/hasselblad",
        "/hasselblad/api",
    ]
    
    results = {}
    
    for endpoint in endpoints:
        url = f"{base_url}{endpoint}"
        try:
            response = requests.get(url, timeout=2)
            if response.status_code < 500:  # 5xx는 서버 에러
                print(f"  📍 {endpoint}: {response.status_code}")
                results[endpoint] = {
                    "status": response.status_code,
                    "headers": dict(response.headers),
                    "content": response.text[:200] if response.text else None
                }
                
                # Content-Type 확인
                content_type = response.headers.get("Content-Type", "")
                if "json" in content_type:
                    try:
                        results[endpoint]["json"] = response.json()
                        print(f"    → JSON 응답 발견!")
                    except:
                        pass
        except requests.exceptions.RequestException as e:
            pass
    
    return results

def test_ptp_protocol(host: str, port: int = 15740) -> bool:
    """PTP/IP 프로토콜을 테스트합니다"""
    print(f"\n📷 PTP/IP 프로토콜 테스트 (포트 {port})")
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        sock.connect((host, port))
        
        # PTP/IP Init Command Packet
        # Length(4) + Type(4) + GUID(16) + Friendly Name
        init_packet = bytearray()
        
        # Packet length (나중에 설정)
        init_packet.extend([0x00, 0x00, 0x00, 0x00])
        
        # Packet type: Init Command (0x00000001)
        init_packet.extend([0x01, 0x00, 0x00, 0x00])
        
        # GUID (16 bytes - 임의 값)
        init_packet.extend(b'PhotoPinMobile__')
        
        # Friendly Name (Unicode)
        friendly_name = "PhotoPin\x00"
        init_packet.extend(friendly_name.encode('utf-16le'))
        
        # 패킷 길이 설정
        packet_length = len(init_packet)
        init_packet[0:4] = packet_length.to_bytes(4, 'little')
        
        print(f"  → PTP/IP Init 패킷 전송 ({len(init_packet)} bytes)")
        sock.send(init_packet)
        
        # 응답 대기
        response = sock.recv(1024)
        if response:
            print(f"  ✅ PTP/IP 응답 수신: {len(response)} bytes")
            print(f"    → 응답 헤더: {response[:8].hex()}")
            return True
        
        sock.close()
    except Exception as e:
        print(f"  ❌ PTP/IP 연결 실패: {e}")
        return False
    
    return False

def send_gps_data(host: str, port: int, latitude: float, longitude: float):
    """GPS 데이터를 다양한 형식으로 전송 시도"""
    print(f"\n📍 GPS 데이터 전송 테스트")
    
    # 1. JSON 형식으로 POST
    if port in [80, 8080, 443, 8443]:
        endpoints = ["/gps", "/location", "/geotag", "/api/location", "/api/gps"]
        for endpoint in endpoints:
            url = f"http://{host}:{port}{endpoint}"
            data = {
                "latitude": latitude,
                "longitude": longitude,
                "altitude": 0,
                "timestamp": time.time(),
                "accuracy": 5.0
            }
            
            try:
                response = requests.post(url, json=data, timeout=2)
                print(f"  → {endpoint}: {response.status_code}")
                if response.status_code < 400:
                    print(f"    ✅ 성공적인 응답!")
            except:
                pass
    
    # 2. PTP/IP SetDevicePropValue 명령 시도
    if port == 15740:
        print("  → PTP/IP GPS 명령 전송 시도...")
        # PTP 구현은 복잡하므로 생략

def analyze_network_traffic():
    """네트워크 트래픽 캡처 (tcpdump 필요)"""
    print("\n🔍 네트워크 트래픽 분석")
    print("  → Phocus 앱이 카메라와 통신할 때 패킷을 캡처합니다")
    print("  → 별도 터미널에서 실행: sudo tcpdump -i en0 host 192.168.2.1 -w capture.pcap")
    print("  → 분석: tcpdump -r capture.pcap -A")

def main():
    print("="*60)
    print("🎯 Hasselblad X2D II 프로토콜 분석")
    print("="*60)
    
    # 1. 연결 확인
    print(f"\n📡 카메라 연결 확인 ({CAMERA_IP})")
    try:
        response = subprocess.run(
            ["ping", "-c", "1", "-t", "1", CAMERA_IP],
            capture_output=True,
            text=True
        )
        if response.returncode == 0:
            print("  ✅ 카메라 연결됨")
        else:
            print("  ❌ 카메라 연결 안됨 - WiFi 연결을 확인하세요")
            return
    except:
        print("  ⚠️ ping 실행 실패")
    
    # 2. 포트 스캔
    open_ports = scan_ports(CAMERA_IP)
    print(f"\n📊 발견된 포트: {open_ports}")
    
    # 3. HTTP 엔드포인트 테스트
    for port in [p for p in open_ports if p in [80, 8080, 443, 8443]]:
        results = test_http_endpoints(CAMERA_IP, port)
        if results:
            print(f"\n💾 HTTP 엔드포인트 결과 저장")
            with open(f"camera_http_{port}_endpoints.json", "w") as f:
                json.dump(results, f, indent=2, default=str)
    
    # 4. PTP/IP 테스트
    if 15740 in open_ports:
        test_ptp_protocol(CAMERA_IP)
    
    # 5. GPS 데이터 전송 테스트
    test_latitude = 37.5665  # 서울 예시 좌표
    test_longitude = 126.9780
    for port in open_ports:
        send_gps_data(CAMERA_IP, port, test_latitude, test_longitude)
    
    # 6. 트래픽 분석 안내
    analyze_network_traffic()
    
    print("\n" + "="*60)
    print("✅ 분석 완료")
    print("="*60)

if __name__ == "__main__":
    main()