#!/bin/bash

# Phocus 2 앱 BLE 패킷 캡처 스크립트

echo "📱 Phocus 2 앱 패킷 캡처 준비"
echo "================================"

# 1. Bluetooth 패킷 로깅 활성화
echo "1️⃣ Bluetooth 디버그 로깅 활성화..."
sudo defaults write com.apple.bluetooth BluetoothDebugEnabled -bool true
sudo defaults write com.apple.bluetooth PacketLoggerEnabled -bool true

# 2. PacketLogger 실행
echo "2️⃣ PacketLogger 실행 중..."
echo "   Xcode > Window > Devices and Simulators > Open Console 사용 가능"

# 3. iOS 패킷 캡처 옵션
echo ""
echo "📲 iPhone에서 Phocus 2 앱 사용 시:"
echo "   1. iPhone을 Mac에 연결"
echo "   2. Xcode > Devices and Simulators > iPhone 선택"
echo "   3. 'Open Console' 클릭"
echo "   4. 필터: 'bluetooth' 또는 'phocus'"
echo ""

# 4. macOS에서 Bluetooth 스니핑
echo "🖥 macOS Bluetooth 스니핑:"
if [ -f "/System/Library/CoreServices/Applications/Wireless Diagnostics.app" ]; then
    echo "   Wireless Diagnostics 앱 실행 가능"
    echo "   Window > Sniffer 또는 Cmd+5"
fi

# 5. tcpdump로 네트워크 패킷 캡처
echo ""
echo "📡 WiFi 패킷 캡처 (카메라 WiFi 연결 후):"
echo "sudo tcpdump -i en0 -w phocus_wifi.pcap host 192.168.2.1"

# 6. Proxyman 또는 Charles Proxy 사용
echo ""
echo "🔍 HTTP/HTTPS 트래픽 분석:"
echo "   - Proxyman (추천): https://proxyman.io"
echo "   - Charles Proxy: https://www.charlesproxy.com"
echo "   - mitmproxy: brew install mitmproxy"

echo ""
echo "📋 캡처 순서:"
echo "1. 위 도구들 중 하나 실행"
echo "2. Phocus 2 앱 실행"
echo "3. 카메라 Bluetooth 연결"
echo "4. WiFi 활성화 과정 관찰"
echo "5. 캡처된 패킷 분석"

# BLE 스캔 도구
echo ""
echo "🔧 추가 도구:"
echo "   brew install blueutil    # BLE 제어"
echo "   brew install nrfconnect   # Nordic BLE 도구"