#!/bin/bash

echo "================================================"
echo "🎯 개선된 BLE 패킷 캡처 가이드"
echo "================================================"
echo ""

echo "📱 세 가지 캡처 방법을 제공합니다:"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "방법 1: PacketLogger 사용 (추천) 🌟"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣ PacketLogger 다운로드:"
echo "   • https://developer.apple.com/download/all/"
echo "   • 'Additional Tools for Xcode' 검색"
echo "   • Hardware > PacketLogger.app"
echo ""
echo "2️⃣ PacketLogger 실행:"
if [ -d "/Applications/PacketLogger.app" ]; then
    echo "   ✅ PacketLogger가 설치되어 있습니다!"
    echo "   실행: open /Applications/PacketLogger.app"
else
    echo "   ❌ PacketLogger가 설치되지 않았습니다."
    echo "   위 링크에서 다운로드하세요."
fi
echo ""
echo "3️⃣ 캡처 설정:"
echo "   • File > New iOS Trace"
echo "   • iPhone 연결 확인"
echo "   • 'Live Capture' 시작"
echo ""
echo "4️⃣ 필터 설정:"
echo "   • ATT (Attribute Protocol) 체크"
echo "   • GATT 체크"
echo "   • L2CAP 체크"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "방법 2: Bluetooth Explorer 사용"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣ Bluetooth Explorer 실행:"
if [ -d "/Applications/Bluetooth Explorer.app" ]; then
    echo "   ✅ Bluetooth Explorer가 설치되어 있습니다!"
    echo "   실행: open '/Applications/Bluetooth Explorer.app'"
else
    echo "   ❌ Bluetooth Explorer가 설치되지 않았습니다."
    echo "   Additional Tools for Xcode에서 다운로드하세요."
fi
echo ""
echo "2️⃣ 설정:"
echo "   • Tools > Packet Logger"
echo "   • iPhone 선택"
echo "   • Start Capture"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "방법 3: Console + 로그 레벨 상세 설정"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣ 디버그 프로파일 설치:"
cat > /tmp/bluetooth_debug.mobileconfig << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.system.logging</string>
            <key>PayloadIdentifier</key>
            <string>com.apple.bluetooth.logging</string>
            <key>PayloadUUID</key>
            <string>$(uuidgen)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadDisplayName</key>
            <string>Bluetooth Debug Logging</string>
            <key>Subsystems</key>
            <dict>
                <key>com.apple.bluetooth</key>
                <dict>
                    <key>DEFAULT-OPTIONS</key>
                    <dict>
                        <key>Level</key>
                        <dict>
                            <key>Enable</key>
                            <string>Debug</string>
                            <key>Persist</key>
                            <string>Debug</string>
                        </dict>
                    </dict>
                </dict>
            </dict>
        </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>Bluetooth Debug Profile</string>
    <key>PayloadIdentifier</key>
    <string>com.photopin.bluetooth.debug</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>$(uuidgen)</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
EOF

echo "   프로파일 생성됨: /tmp/bluetooth_debug.mobileconfig"
echo "   iPhone에 설치: 설정 > 일반 > VPN 및 기기 관리"
echo ""

echo "2️⃣ Console 명령줄 사용:"
echo "   다음 명령으로 실시간 캡처:"
echo ""
echo "   # iPhone 로그 스트리밍 (USB 연결 필요)"
echo "   log stream --device --predicate 'subsystem == \"com.apple.bluetooth\"' --debug --info > ble_capture.log"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 캡처 시 찾아야 할 핵심 정보"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Service Discovery:"
echo "   • Service UUID: FFF0"
echo "   • Characteristic 목록"
echo ""
echo "2. Write Commands:"
echo "   • Handle (예: 0x0013)"
echo "   • Value (hex bytes)"
echo "   • Response"
echo ""
echo "3. 시퀀스:"
echo "   • 연결 → 서비스 검색 → Write 명령 → WiFi 활성화"
echo ""
echo "4. 타이밍:"
echo "   • 각 명령 사이 간격"
echo "   • Response 대기 시간"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 캡처 절차"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 위 도구 중 하나 선택하여 실행"
echo "2. 캡처 시작"
echo "3. Phocus 2 앱 실행"
echo "4. 카메라 Bluetooth 연결"
echo "5. WiFi가 활성화될 때까지 대기"
echo "6. 캡처 중지 및 저장"
echo ""

# 자동 실행 스크립트
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 자동 캡처 시작"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Console 로그 스트리밍을 시작하시겠습니까? (y/n)"
read -r response

if [[ "$response" == "y" ]]; then
    LOG_FILE="/Users/munkyo/works/ai-code/photo/PhotoPinMobile/logs/ble_detailed_$(date +%Y%m%d_%H%M%S).log"
    
    echo ""
    echo "📍 로그 파일: $LOG_FILE"
    echo ""
    echo "🔴 캡처 중... (종료: Ctrl+C)"
    echo ""
    echo "지금 Phocus 앱으로 카메라를 연결하세요!"
    echo ""
    
    # 로그 스트리밍 시작
    log stream --device --predicate '
        subsystem == "com.apple.bluetooth" OR 
        processImagePath CONTAINS "Phocus" OR
        eventMessage CONTAINS "FFF" OR
        eventMessage CONTAINS "characteristic" OR
        eventMessage CONTAINS "write"
    ' --debug --info | tee "$LOG_FILE"
else
    echo ""
    echo "수동으로 PacketLogger나 Bluetooth Explorer를 사용하세요."
fi