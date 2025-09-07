#!/usr/bin/env python3
"""
Hasselblad X2D II USB 연결 분석 도구
USB를 통해 카메라와 통신하여 프로토콜 분석
"""

import usb.core
import usb.util
import struct
import time
from datetime import datetime

# Hasselblad USB ID (추정값 - 실제 값은 lsusb로 확인)
VENDOR_ID = 0x0AA8  # Hasselblad 추정
PRODUCT_ID = None   # 자동 검색

def find_hasselblad_camera():
    """USB 연결된 Hasselblad 카메라 찾기"""
    print("🔍 USB 장치 검색 중...")
    
    # 모든 USB 장치 나열
    devices = usb.core.find(find_all=True)
    
    for device in devices:
        vendor = device.idVendor
        product = device.idProduct
        
        try:
            manufacturer = usb.util.get_string(device, device.iManufacturer)
            product_name = usb.util.get_string(device, device.iProduct)
            
            print(f"📷 발견: {manufacturer} - {product_name}")
            print(f"   Vendor ID: 0x{vendor:04x}")
            print(f"   Product ID: 0x{product:04x}")
            
            # Hasselblad 카메라 확인
            if "Hasselblad" in str(manufacturer) or "X2D" in str(product_name):
                print(f"✅ Hasselblad 카메라 발견!")
                return device
                
        except:
            pass
    
    return None

def analyze_usb_communication(device):
    """USB 통신 분석"""
    print("\n📊 USB 통신 분석 시작...")
    
    # 설정 정보
    cfg = device.get_active_configuration()
    print(f"Configuration: {cfg.bConfigurationValue}")
    
    # 인터페이스 정보
    for interface in cfg:
        print(f"\n인터페이스 {interface.bInterfaceNumber}:")
        print(f"  클래스: 0x{interface.bInterfaceClass:02x}")
        print(f"  서브클래스: 0x{interface.bInterfaceSubClass:02x}")
        print(f"  프로토콜: 0x{interface.bInterfaceProtocol:02x}")
        
        # PTP/MTP 인터페이스 확인 (카메라 통신)
        if interface.bInterfaceClass == 0x06:  # Still Image
            print("  ✅ PTP/MTP 인터페이스 발견!")
            analyze_ptp_commands(device, interface)
            
        # 엔드포인트 정보
        for ep in interface:
            print(f"  엔드포인트 0x{ep.bEndpointAddress:02x}:")
            print(f"    방향: {'IN' if ep.bEndpointAddress & 0x80 else 'OUT'}")
            print(f"    타입: {ep.bmAttributes & 0x03}")

def analyze_ptp_commands(device, interface):
    """PTP 명령 분석"""
    print("\n🔧 PTP 명령 테스트...")
    
    # PTP 명령 코드
    PTP_COMMANDS = {
        0x1001: "GetDeviceInfo",
        0x1002: "OpenSession",
        0x1003: "CloseSession",
        0x1004: "GetStorageIDs",
        0x9201: "GetObjectPropsSupported",  # 카메라 특정
        0x9202: "GetObjectPropDesc",
        0x9801: "GetDevicePropDesc",  # WiFi 설정 관련
    }
    
    # WiFi 관련 속성 코드 (추정)
    WIFI_PROPS = {
        0xD001: "WiFi_Enable",
        0xD002: "WiFi_SSID",
        0xD003: "WiFi_Password",
        0xD004: "WiFi_Mode",  # AP/Client
        0xD005: "WiFi_Status",
    }
    
    print("\nWiFi 관련 속성 확인:")
    for prop_code, prop_name in WIFI_PROPS.items():
        print(f"  {prop_name} (0x{prop_code:04x})")
        # 실제 명령 전송 코드는 pyusb 설정 필요

def monitor_usb_traffic():
    """USB 트래픽 모니터링"""
    print("\n📡 USB 트래픽 모니터링...")
    print("USBPcap 또는 Wireshark 사용 권장")
    print("macOS: sudo tcpdump -i XHC20")
    
    # USB 모니터링 명령
    commands = [
        "# USB 장치 목록",
        "system_profiler SPUSBDataType",
        "",
        "# USB 트래픽 캡처 (Wireshark 필요)",
        "sudo tcpdump -i XHC20 -w hasselblad_usb.pcap",
        "",
        "# ioreg로 USB 정보 확인",
        "ioreg -p IOUSB -l -w 0 | grep -i hasselblad",
    ]
    
    print("\n유용한 명령어:")
    for cmd in commands:
        print(f"  {cmd}")

def main():
    print("=" * 50)
    print("Hasselblad X2D II USB 프로토콜 분석")
    print("=" * 50)
    
    # 1. USB 카메라 찾기
    camera = find_hasselblad_camera()
    
    if not camera:
        print("\n❌ Hasselblad 카메라를 찾을 수 없습니다.")
        print("💡 카메라를 USB-C로 연결하고 전원을 켜세요.")
        
        # 대신 모든 USB 장치 표시
        print("\n현재 연결된 USB 장치:")
        import subprocess
        result = subprocess.run(["system_profiler", "SPUSBDataType"], 
                              capture_output=True, text=True)
        print(result.stdout)
        return
    
    # 2. USB 통신 분석
    try:
        analyze_usb_communication(camera)
    except usb.core.USBError as e:
        print(f"\n⚠️ USB 접근 오류: {e}")
        print("💡 sudo로 실행하거나 권한 설정이 필요할 수 있습니다.")
    
    # 3. 모니터링 안내
    monitor_usb_traffic()
    
    print("\n✅ 분석 완료!")
    print("📋 다음 단계:")
    print("1. Phocus 2 앱을 실행하여 정상 동작 캡처")
    print("2. 캡처된 패킷과 비교 분석")
    print("3. WiFi 활성화 명령 시퀀스 파악")

if __name__ == "__main__":
    # pyusb 설치 확인
    try:
        import usb
    except ImportError:
        print("⚠️ pyusb가 설치되지 않았습니다.")
        print("실행: pip3 install pyusb")
        exit(1)
    
    main()