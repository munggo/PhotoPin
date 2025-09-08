#!/bin/bash

# Phocus 프로토콜 캡처 스크립트

echo "🎯 Phocus BLE 프로토콜 캡처 시작"
echo "================================"

# 로그 디렉토리 생성
mkdir -p logs

# 타임스탬프
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/phocus_protocol_${TIMESTAMP}.log"

echo "📝 로그 파일: $LOG_FILE"
echo ""
echo "📋 테스트 순서:"
echo "1. 이 스크립트를 실행한 상태로 유지"
echo "2. Phocus 2 앱 실행"
echo "3. 카메라 연결"
echo "4. WiFi가 활성화되면 iPhone 설정에서 확인"
echo "5. 완료 후 Ctrl+C로 종료"
echo ""
echo "🔴 캡처 중... (Ctrl+C로 종료)"

# 더 상세한 필터로 캡처
log stream --device \
  --predicate '(subsystem == "com.apple.bluetooth" OR 
                subsystem == "com.apple.CoreBluetooth" OR 
                process == "bluetoothd" OR 
                process == "Phocus 2" OR
                process == "Phocus" OR
                eventMessage CONTAINS "FFF" OR 
                eventMessage CONTAINS[c] "characteristic" OR 
                eventMessage CONTAINS[c] "write" OR 
                eventMessage CONTAINS[c] "read" OR
                eventMessage CONTAINS[c] "notify" OR
                eventMessage CONTAINS "0x" OR 
                eventMessage CONTAINS "hasselblad" OR 
                eventMessage CONTAINS "X2D" OR
                eventMessage CONTAINS "CBPeripheral" OR
                eventMessage CONTAINS "didWrite" OR
                eventMessage CONTAINS "didUpdate") AND
               (eventMessage CONTAINS "FFF" OR 
                eventMessage CONTAINS "Phocus" OR
                eventMessage CONTAINS "X2D")' \
  --level debug \
  --style json > "$LOG_FILE" 2>&1 &

CAPTURE_PID=$!

# 종료 시 정리
trap "echo ''; echo '✅ 캡처 완료. 로그 분석 중...'; kill $CAPTURE_PID 2>/dev/null; python3 analyze_phocus_log.py '$LOG_FILE'" EXIT

# 대기
wait $CAPTURE_PID