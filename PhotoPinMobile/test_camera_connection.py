#!/usr/bin/env python3
"""
Hasselblad X2D II 카메라 연결 테스트
간단한 연결 테스트와 포트 스캔
"""

import socket
import subprocess
import sys

CAMERA_IP = "192.168.2.1"

def check_connection():
    """카메라 연결 확인"""
    print("📡 카메라 연결 확인...")
    try:
        result = subprocess.run(
            ["ping", "-c", "1", "-t", "1", CAMERA_IP],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print(f"✅ {CAMERA_IP} 연결됨")
            return True
        else:
            print(f"❌ {CAMERA_IP} 연결 안됨")
            print("💡 Phocus로 WiFi를 먼저 활성화하세요")
            return False
    except Exception as e:
        print(f"⚠️ ping 실패: {e}")
        return False

def quick_port_scan():
    """주요 포트만 빠르게 스캔"""
    print("\n🔍 포트 스캔 중...")
    
    # 카메라가 사용할 가능성이 높은 포트
    ports_to_check = [
        (80, "HTTP"),
        (443, "HTTPS"),
        (8080, "Alternative HTTP"),
        (8443, "Alternative HTTPS"),
        (15740, "PTP/IP"),
        (5353, "mDNS"),
        (1900, "UPnP"),
        (9000, "Camera Control"),
        (554, "RTSP"),
        (21, "FTP"),
        (22, "SSH"),
        (23, "Telnet"),
        (8008, "HTTP Alt"),
        (8888, "HTTP Alt2"),
        (3000, "Dev Server"),
        (5000, "Flask/Control"),
    ]
    
    open_ports = []
    
    for port, description in ports_to_check:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.5)
        result = sock.connect_ex((CAMERA_IP, port))
        if result == 0:
            print(f"  ✅ 포트 {port:5} 열림 - {description}")
            open_ports.append(port)
        sock.close()
    
    return open_ports

def test_http_port(port):
    """HTTP GET 요청 테스트"""
    import http.client
    
    print(f"\n🌐 HTTP 테스트 (포트 {port})")
    
    try:
        conn = http.client.HTTPConnection(CAMERA_IP, port, timeout=2)
        conn.request("GET", "/")
        response = conn.getresponse()
        
        print(f"  상태 코드: {response.status}")
        print(f"  헤더:")
        for header, value in response.headers.items():
            print(f"    {header}: {value}")
        
        # 응답 내용 일부 출력
        content = response.read(500).decode('utf-8', errors='ignore')
        if content:
            print(f"  내용 (처음 500자):")
            print(f"    {content[:500]}")
        
        conn.close()
        return True
    except Exception as e:
        print(f"  ❌ HTTP 연결 실패: {e}")
        return False

def main():
    print("="*60)
    print("🎯 Hasselblad X2D II 연결 테스트")
    print("="*60)
    
    # 1. 연결 확인
    if not check_connection():
        print("\n⚠️ 카메라 연결 후 다시 실행하세요")
        print("1. Phocus 2 앱으로 Bluetooth 연결")
        print("2. WiFi가 활성화될 때까지 대기")
        print("3. 이 스크립트 다시 실행")
        return
    
    # 2. 포트 스캔
    open_ports = quick_port_scan()
    
    if not open_ports:
        print("\n❌ 열린 포트를 찾을 수 없습니다")
        return
    
    print(f"\n📊 발견된 포트: {open_ports}")
    
    # 3. HTTP 포트 테스트
    http_ports = [p for p in open_ports if p in [80, 443, 8080, 8443, 8008, 8888]]
    for port in http_ports:
        test_http_port(port)
    
    # 4. PTP/IP 포트 확인
    if 15740 in open_ports:
        print("\n📷 PTP/IP 포트(15740) 발견!")
        print("  → PTP/IP는 복잡한 프로토콜이므로 별도 구현 필요")
    
    print("\n" + "="*60)
    print("✅ 테스트 완료")
    print("="*60)

if __name__ == "__main__":
    main()