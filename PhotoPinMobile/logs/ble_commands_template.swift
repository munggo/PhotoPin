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
