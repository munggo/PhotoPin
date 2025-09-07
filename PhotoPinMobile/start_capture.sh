#!/bin/bash

LOG_FILE="/Users/munkyo/works/ai-code/photo/PhotoPinMobile/logs/ble_capture_$(date +%Y%m%d_%H%M%S).log"

echo "================================================"
echo "🎯 BLE 패킷 캡처 시작"
echo "================================================"
echo ""
echo "📱 체크리스트:"
echo "✓ iPhone이 USB로 연결됨"
echo "✓ 카메라 전원이 켜져있음"
echo "✓ Phocus 2 앱이 설치됨"
echo ""
echo "📝 로그 파일: $LOG_FILE"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 다음 순서를 정확히 따라주세요:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 이 스크립트를 실행한 상태로 유지"
echo "2. iPhone에서 Phocus 2 앱 실행"
echo "3. 카메라 선택하여 Bluetooth 연결"
echo "4. WiFi가 활성화되면 (설정에서 SSID 확인)"
echo "5. Ctrl+C로 캡처 종료"
echo ""
echo "준비되면 Enter를 눌러 캡처를 시작하세요..."
read -p ""

echo ""
echo "🔴 캡처 중... (종료: Ctrl+C)"
echo ""

# 로그 스트리밍 시작 - 더 상세한 필터
log stream --device --predicate '
    subsystem == "com.apple.bluetooth" OR 
    subsystem == "com.apple.CoreBluetooth" OR
    process == "bluetoothd" OR
    process == "Phocus 2" OR
    eventMessage CONTAINS "FFF" OR
    eventMessage CONTAINS[c] "characteristic" OR
    eventMessage CONTAINS[c] "write" OR
    eventMessage CONTAINS[c] "0x" OR
    eventMessage CONTAINS "hasselblad" OR
    eventMessage CONTAINS "X2D"
' --level debug --style json > "$LOG_FILE"
