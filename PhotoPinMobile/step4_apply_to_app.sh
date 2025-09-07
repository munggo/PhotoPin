#!/bin/bash

echo "================================================"
echo "🔧 STEP 4: 분석 결과를 앱에 적용"
echo "================================================"
echo ""

LOG_DIR="/Users/munkyo/works/ai-code/photo/PhotoPinMobile/logs"
ANALYSIS_FILE="$LOG_DIR/ble_analysis.txt"
PROJECT_DIR="/Users/munkyo/works/ai-code/photo/PhotoPinMobile/XcodeProject"

echo "📋 적용할 변경사항 체크리스트:"
echo ""
echo "1️⃣ BLE 명령 시퀀스 업데이트"
echo "   - 캡처된 정확한 명령 순서 적용"
echo "   - 명령 간 적절한 딜레이 추가"
echo "   - 응답 확인 로직 강화"
echo ""

echo "2️⃣ WiFi 활성화 프로세스"
echo "   - AP 모드 활성화 타이밍"
echo "   - SSID 브로드캐스트 시작"
echo "   - NEHotspotConfiguration 호출 시점"
echo ""

echo "3️⃣ 에러 처리 개선"
echo "   - 타임아웃 처리"
echo "   - 재시도 로직"
echo "   - 상태 복구"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 수정 가이드"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 템플릿 코드 생성
cat > "$LOG_DIR/ble_commands_template.swift" << 'EOF'
// 📍 BluetoothCameraManager.swift에 적용할 코드

// MARK: - Phocus 앱에서 리버스 엔지니어링한 정확한 명령 시퀀스
private func activateWiFiWithPhocusSequence() async throws {
    logger.log("🔄 Phocus 시퀀스로 WiFi 활성화 시작")
    
    // 캡처된 로그에서 추출한 실제 명령들
    // 예시 (실제 캡처 데이터로 교체 필요):
    
    let phocusCommands: [(String, Data, TimeInterval)] = [
        // (설명, 데이터, 다음 명령까지 딜레이)
        ("초기화", Data([0x00, 0x00, 0x01]), 0.1),
        ("WiFi 모듈 활성화", Data([0x01, 0x01, 0x00]), 0.2),
        ("AP 모드 설정", Data([0x04, 0x01, 0x00]), 0.3),
        ("SSID 설정", Data([0x05] + "X2D-II".data(using: .utf8)!), 0.2),
        ("브로드캐스트 시작", Data([0x0D, 0x01, 0x00]), 0.5),
        // ... 실제 캡처된 명령으로 교체
    ]
    
    // FFF3 characteristic에 순차적으로 전송
    guard let characteristic = wifiControlCharacteristic else {
        throw WiFiError.characteristicNotFound
    }
    
    for (description, data, delay) in phocusCommands {
        logger.log("📤 전송: \(description)")
        logger.log("   데이터: \(data.hexString)")
        
        peripheral?.writeValue(data, for: characteristic, type: .withResponse)
        
        // 응답 대기
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // 상태 확인 (FFF5에서 읽기)
        if let statusChar = statusCharacteristic {
            peripheral?.readValue(for: statusChar)
        }
    }
    
    // WiFi가 활성화될 때까지 대기
    logger.log("⏳ WiFi 브로드캐스트 대기 중...")
    try await Task.sleep(nanoseconds: 2_000_000_000) // 2초
    
    // WiFi 네트워크 스캔
    await scanForWiFiNetwork()
}

// MARK: - 개선된 WiFi 스캔
private func scanForWiFiNetwork() async {
    logger.log("📡 WiFi 네트워크 스캔 시작")
    
    // 가능한 SSID 패턴들
    let possibleSSIDs = [
        "X2D",
        "X2D-II",
        "Hasselblad",
        "Hasselblad-X2D",
        // 실제 SSID 패턴 추가
    ]
    
    for ssid in possibleSSIDs {
        logger.log("🔍 SSID 검색: \(ssid)")
        
        let configuration = NEHotspotConfiguration(ssid: ssid)
        configuration.joinOnce = false
        
        do {
            try await NEHotspotConfigurationManager.shared.apply(configuration)
            logger.log("✅ WiFi 연결 성공: \(ssid)")
            currentSSID = ssid
            break
        } catch {
            logger.log("❌ \(ssid) 연결 실패: \(error)")
        }
    }
}

// MARK: - Notification 처리 개선
func peripheral(_ peripheral: CBPeripheral, 
                didUpdateValueFor characteristic: CBCharacteristic, 
                error: Error?) {
    
    guard error == nil, let value = characteristic.value else { return }
    
    let uuid = characteristic.uuid.uuidString
    logger.log("📥 알림 수신: \(uuid)")
    logger.log("   데이터: \(value.hexString)")
    
    // 상태 업데이트 파싱
    switch uuid.uppercased() {
    case "FFF5": // 상태
        parseStatusUpdate(value)
    case "FFF7": // 알림
        parseNotification(value)
    default:
        break
    }
}

private func parseStatusUpdate(_ data: Data) {
    // WiFi 상태 확인
    // 예: 첫 번째 바이트가 0x01이면 WiFi 활성
    if data.count > 0 && data[0] == 0x01 {
        logger.log("✅ WiFi 활성 상태 확인됨")
        DispatchQueue.main.async {
            self.isWiFiActive = true
        }
    }
}

// Data Extension for Hex String
extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
EOF

echo "📄 템플릿 코드 생성됨:"
echo "   $LOG_DIR/ble_commands_template.swift"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛠 Xcode 프로젝트 업데이트"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "1. BluetoothCameraManager.swift 열기:"
echo "   open $PROJECT_DIR/PhotoPin/BluetoothCameraManager.swift"
echo ""

echo "2. 분석 결과 확인:"
if [ -f "$ANALYSIS_FILE" ]; then
    echo "   open $ANALYSIS_FILE"
else
    echo "   ⚠️ 분석 파일이 없습니다. step3를 먼저 실행하세요."
fi
echo ""

echo "3. 템플릿 코드 참조:"
echo "   open $LOG_DIR/ble_commands_template.swift"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 적용 후 테스트"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Xcode에서 Clean Build (Shift+Cmd+K)"
echo "2. iPhone에 앱 설치"
echo "3. 디버그 탭에서 로그 확인"
echo "4. 카메라 연결 시도"
echo ""

echo "🎯 성공 지표:"
echo "✓ Bluetooth 연결 성공"
echo "✓ WiFi SSID가 iPhone 설정에 표시"
echo "✓ WiFi 자동 연결"
echo "✓ 192.168.2.1 접속 가능"
echo ""

echo "문제 발생 시:"
echo "• Console 앱으로 추가 로그 캡처"
echo "• 명령 타이밍 조정"
echo "• 다른 SSID 패턴 시도"