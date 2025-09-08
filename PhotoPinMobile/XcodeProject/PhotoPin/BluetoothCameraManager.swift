import Foundation
import CoreBluetooth
import Network
import CoreLocation
import NetworkExtension
import SystemConfiguration.CaptiveNetwork

class BluetoothCameraManager: NSObject, ObservableObject {
    @Published var isBluetoothConnected = false
    @Published var isWiFiConnected = false
    @Published var cameraInfo = "카메라 검색 중..."
    @Published var photoCount = 0
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var allDiscoveredDevices: [(peripheral: CBPeripheral, name: String, rssi: NSNumber)] = []
    @Published var isScanning = false
    @Published var debugLog: String = ""
    @Published var wifiSSID: String = ""
    @Published var wifiPassword: String = ""
    
    // WiFiScanner 기능 내장 (별도 파일 불필요)
    @Published var availableNetworks: [String] = []
    @Published var currentSSID: String = ""
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var wifiConnection: NWConnection?
    private var wifiCharacteristic: CBCharacteristic?
    private var cameraCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var connectionRetryCount = 0
    private let maxRetries = 3
    
    // WiFi 초기화 상태 추적
    private var wifiInitialized = false
    private var characteristicsReady = false
    
    // Hasselblad 서비스 UUID (추정값 - 실제 값은 스캔으로 확인)
    private let hasselbladServiceUUID = CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB") // Device Information
    private let cameraControlUUID = CBUUID(string: "00001800-0000-1000-8000-00805F9B34FB") // Generic Access
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // WiFi 모니터링 시작
        startWiFiMonitoring()
    }
    
    func startScanning() {
        if centralManager.state == .poweredOn {
            isScanning = true
            cameraInfo = "모든 Bluetooth 장치 검색 중..."
            allDiscoveredDevices.removeAll()
            discoveredDevices.removeAll()
            
            // 모든 장치 스캔 (UUID 필터 없이)
            centralManager.scanForPeripherals(withServices: nil, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ])
            
            // 20초 후 스캔 중지 (더 긴 스캔 시간)
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                self.stopScanning()
            }
        } else {
            cameraInfo = "Bluetooth가 꺼져있거나 권한이 없습니다"
        }
    }
    
    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
        
        if allDiscoveredDevices.isEmpty {
            cameraInfo = "장치를 찾을 수 없음"
        } else {
            cameraInfo = "\(allDiscoveredDevices.count)개 장치 발견"
        }
    }
    
    func connectToDevice(_ peripheral: CBPeripheral) {
        print("🔷 연결 시도: \(peripheral.name ?? "Unknown")")
        print("🔷 Peripheral ID: \(peripheral.identifier)")
        
        // 스캔 중지
        if isScanning {
            centralManager.stopScan()
            isScanning = false
        }
        
        connectedPeripheral = peripheral
        peripheral.delegate = self
        
        cameraInfo = "연결 시도 중: \(peripheral.name ?? "Unknown")"
        
        // 연결 옵션 설정
        let options: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ]
        
        centralManager.connect(peripheral, options: options)
        
        // 30초 타임아웃 설정
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self else { return }
            if !self.isBluetoothConnected {
                print("❌ 연결 타임아웃")
                self.cameraInfo = "연결 시간 초과"
                self.centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }
    
    private func enableWiFiOnCamera() {
        // 블루투스를 통해 Wi-Fi 활성화 명령 전송
        guard let peripheral = connectedPeripheral else { return }
        
        // 서비스 검색
        peripheral.discoverServices(nil)
        
        cameraInfo = "Wi-Fi 활성화 중..."
        
        // Wi-Fi 활성화 후 연결
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.connectToWiFi()
        }
    }
    
    private func connectToWiFi() {
        addDebugLog("📶 Wi-Fi 연결 준비...")
        
        // 카메라 고유 번호에 따른 SSID 패턴
        let cameraSerial = "003635"
        let possibleSSIDs = [
            "X2D-II-100C-\(cameraSerial)",
            "X2D II 100C \(cameraSerial)",
            "Hasselblad-\(cameraSerial)",
            "X2D-\(cameraSerial)"
        ]
        
        // WiFi 스캔 트리거
        DispatchQueue.main.async {
            self.cameraInfo = """
            📡 BLE 명령 전송 완료
            
            📱 iPhone WiFi 새로고침 필요:
            1. 설정 > Wi-Fi 열기
            2. WiFi를 끄고 다시 켜기
            3. 카메라 SSID 찾기:
               • X2D-II-100C-003635
               • X2D II 100C 003635
            
            ⏳ 자동 감지 시도 중...
            """
            
            // NEHotspotConfiguration으로 강제 스캔 시도
            self.forceScanWiFiNetworks()
        }
        
        // 현재 연결된 WiFi 확인
        checkCurrentWiFi()
        
        // 주기적으로 WiFi 상태 확인 (수동 연결 감지)
        startWiFiMonitoring()
        
        // 10초마다 연결 확인 시도
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.addDebugLog("🔍 WiFi 연결 재확인...")
            self?.checkCurrentWiFi()
            self?.checkWiFiConnection()
        }
    }
    
    // NEHotspotConfiguration을 사용한 자동 WiFi 연결
    private func connectToWiFiNetwork(ssid: String, password: String) {
        addDebugLog("NEHotspotConfiguration으로 \(ssid) 연결 시도")
        
        let configuration: NEHotspotConfiguration
        if password.isEmpty {
            configuration = NEHotspotConfiguration(ssid: ssid)
        } else {
            configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        }
        
        configuration.joinOnce = false // 영구 저장
        
        NEHotspotConfigurationManager.shared.apply(configuration) { [weak self] error in
            if let error = error {
                self?.addDebugLog("❌ WiFi 연결 실패: \(error.localizedDescription)")
                
                // 에러 코드에 따른 처리
                if let nsError = error as NSError? {
                    switch nsError.code {
                    case NEHotspotConfigurationError.alreadyAssociated.rawValue:
                        self?.addDebugLog("✅ 이미 연결됨")
                        self?.checkWiFiConnection()
                    case NEHotspotConfigurationError.userDenied.rawValue:
                        self?.addDebugLog("⚠️ 사용자가 거부함")
                        DispatchQueue.main.async {
                            self?.cameraInfo = "WiFi 연결 권한이 필요합니다"
                        }
                    case NEHotspotConfigurationError.invalidSSID.rawValue:
                        self?.addDebugLog("⚠️ 잘못된 SSID")
                    case NEHotspotConfigurationError.invalidWPAPassphrase.rawValue:
                        self?.addDebugLog("⚠️ 잘못된 비밀번호")
                        DispatchQueue.main.async {
                            self?.cameraInfo = "비밀번호가 올바르지 않습니다"
                        }
                    default:
                        self?.addDebugLog("⚠️ 알 수 없는 에러: \(nsError.code)")
                    }
                }
            } else {
                self?.addDebugLog("✅ WiFi 구성 적용 성공")
                // 연결 확인
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.checkWiFiConnection()
                }
            }
        }
    }
    
    // 현재 연결된 WiFi 확인
    private func checkCurrentWiFi() {
        // 현재 WiFi SSID 가져오기
        if let currentSSID = getCurrentWiFiSSID() {
            addDebugLog("현재 WiFi: \(currentSSID)")
            self.currentSSID = currentSSID
            
            // Hasselblad WiFi인지 확인
            if isHasselbladNetwork(currentSSID) {
                addDebugLog("✅ Hasselblad WiFi 감지!")
                self.wifiSSID = currentSSID
                DispatchQueue.main.async {
                    self.cameraInfo = "카메라 WiFi 연결됨: \(currentSSID)"
                    self.isWiFiConnected = true
                }
                checkWiFiConnection()
            } else {
                addDebugLog("⚠️ 다른 WiFi에 연결됨: \(currentSSID)")
            }
        } else {
            addDebugLog("❌ WiFi 연결 없음")
        }
    }
    
    // WiFi SSID 가져오기
    private func getCurrentWiFiSSID() -> String? {
        var ssid: String?
        
        if let interfaces = CNCopySupportedInterfaces() as? [String] {
            for interface in interfaces {
                if let networkInfo = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any] {
                    ssid = networkInfo[kCNNetworkInfoKeySSID as String] as? String
                    break
                }
            }
        }
        
        return ssid
    }
    
    // Hasselblad 네트워크인지 확인
    private func isHasselbladNetwork(_ ssid: String) -> Bool {
        let patterns = [
            "X2D-II-100C",
            "X2D II 100C",
            "Hasselblad",
            "X2D"
        ]
        
        for pattern in patterns {
            if ssid.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    // WiFi 상태 모니터링
    private func startWiFiMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkCurrentWiFi()
        }
    }
    
    // WiFi 네트워크 강제 스캔
    private func forceScanWiFiNetworks() {
        addDebugLog("🔍 WiFi 네트워크 강제 스캔 시작")
        
        let possibleSSIDs = [
            "X2D-II-100C-003635",
            "X2D II 100C 003635",
            "Hasselblad-003635",
            "X2D-003635"
        ]
        
        // 각 SSID에 대해 연결 시도 (이렇게 하면 iOS가 WiFi를 스캔함)
        for ssid in possibleSSIDs {
            let configuration = NEHotspotConfiguration(ssid: ssid)
            configuration.joinOnce = true
            
            NEHotspotConfigurationManager.shared.apply(configuration) { [weak self] error in
                if error == nil {
                    self?.addDebugLog("✅ \(ssid) 발견 및 연결 시도")
                    self?.wifiSSID = ssid
                    DispatchQueue.main.async {
                        self?.cameraInfo = "카메라 WiFi 발견: \(ssid)"
                        self?.isWiFiConnected = true
                    }
                    self?.checkWiFiConnection()
                } else if let nsError = error as NSError?,
                          nsError.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                    self?.addDebugLog("✅ 이미 \(ssid)에 연결됨")
                    self?.wifiSSID = ssid
                    self?.isWiFiConnected = true
                    self?.checkWiFiConnection()
                }
            }
        }
    }
    
    private func checkWiFiConnection() {
        addDebugLog("🔗 카메라 연결 확인 시작")
        
        // 다양한 가능한 카메라 IP 시도
        let possibleHosts = [
            "192.168.2.1",    // Hasselblad 카메라 가능성 높음
            "192.168.1.1",    // 일반적인 카메라 AP IP
            "192.168.0.1",    // 대체 IP
            "192.168.4.1",    // 다른 카메라 브랜드
            "10.0.0.1",       // 다른 가능한 IP
            "172.20.10.1"     // iPhone 핫스팟 범위
        ]
        
        // 첫 번째 IP부터 시도
        tryConnection(hosts: possibleHosts, index: 0)
    }
    
    private func tryConnection(hosts: [String], index: Int) {
        guard index < hosts.count else {
            addDebugLog("❌ 모든 IP 연결 실패")
            DispatchQueue.main.async {
                self.cameraInfo = "카메라 연결 실패 - WiFi 확인 필요"
            }
            return
        }
        
        let cameraHost = hosts[index]
        let cameraPort: UInt16 = 80
        
        addDebugLog("시도: \(cameraHost):\(cameraPort)")
        
        let host = NWEndpoint.Host(cameraHost)
        let port = NWEndpoint.Port(rawValue: cameraPort)!
        
        // TCP 파라미터 설정 (프록시 무시)
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        tcpOptions.connectionTimeout = 10
        
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.prohibitedInterfaceTypes = [.cellular] // 셀룰러 제외
        params.requiredInterfaceType = .wifi // Wi-Fi만 사용
        params.preferNoProxies = true // 프록시 사용 안함
        
        wifiConnection = NWConnection(host: host, port: port, using: params)
        
        wifiConnection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.addDebugLog("✅ \(cameraHost) 연결 성공!")
                    self?.isWiFiConnected = true
                    self?.connectionRetryCount = 0
                    DispatchQueue.main.async {
                        self?.cameraInfo = "Hasselblad X2D II - 연결됨"
                    }
                    self?.sendHandshake()
                case .waiting(let error):
                    self?.addDebugLog("⏳ 대기: \(error)")
                    DispatchQueue.main.async {
                        self?.cameraInfo = "Wi-Fi 연결 중..."
                    }
                case .failed(let error):
                    self?.addDebugLog("❌ \(cameraHost) 실패: \(error)")
                    // 다음 IP 시도
                    self?.tryConnection(hosts: hosts, index: index + 1)
                default:
                    break
                }
            }
        }
        
        wifiConnection?.start(queue: .main)
    }
    
    private func retryWiFiConnection() {
        // 다른 포트로 재시도
        let alternativePorts: [UInt16] = [8080, 8888, 5000, 3000]
        
        for port in alternativePorts {
            print("🔄 포트 \(port)로 재시도...")
            
            let host = NWEndpoint.Host("192.168.1.1")
            let endpoint = NWEndpoint.Port(rawValue: port)!
            
            let testConnection = NWConnection(host: host, port: endpoint, using: .tcp)
            
            testConnection.stateUpdateHandler = { [weak self] state in
                if case .ready = state {
                    print("✅ 포트 \(port)에서 연결 성공!")
                    self?.wifiConnection = testConnection
                    self?.isWiFiConnected = true
                    DispatchQueue.main.async {
                        self?.cameraInfo = "Hasselblad X2D II - 연결됨 (포트: \(port))"
                    }
                }
            }
            
            testConnection.start(queue: .main)
        }
    }
    
    private func sendHandshake() {
        // Phocus 프로토콜 핸드셰이크
        let handshake = """
        {
            "type": "handshake",
            "client": "PhotoPin",
            "version": "1.0",
            "capabilities": ["capture", "gps", "preview"]
        }
        """
        
        if let data = handshake.data(using: .utf8) {
            wifiConnection?.send(content: data, completion: .contentProcessed { _ in
                print("핸드셰이크 전송됨")
            })
        }
        
        // 응답 수신
        receiveData()
    }
    
    private func receiveData() {
        wifiConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                let response = String(data: data, encoding: .utf8) ?? ""
                print("카메라 응답: \(response)")
                
                // 계속 수신
                if !isComplete {
                    self.receiveData()
                }
            }
        }
    }
    
    func capturePhoto(with location: CLLocation?) {
        // 촬영 명령
        let captureCommand = """
        {
            "type": "capture",
            "settings": {
                "format": "raw",
                "gps": {
                    "latitude": \(location?.coordinate.latitude ?? 0),
                    "longitude": \(location?.coordinate.longitude ?? 0),
                    "altitude": \(location?.altitude ?? 0),
                    "timestamp": "\(ISO8601DateFormatter().string(from: location?.timestamp ?? Date()))"
                }
            }
        }
        """
        
        if let data = captureCommand.data(using: .utf8) {
            wifiConnection?.send(content: data, completion: .contentProcessed { _ in
                DispatchQueue.main.async {
                    self.photoCount += 1
                }
            })
        }
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        wifiConnection?.cancel()
        isBluetoothConnected = false
        isWiFiConnected = false
        cameraInfo = "연결 해제됨"
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothCameraManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth 켜짐")
            startScanning()
        case .poweredOff:
            cameraInfo = "Bluetooth가 꺼져있습니다"
        case .unauthorized:
            cameraInfo = "Bluetooth 권한이 필요합니다"
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // 모든 장치 로깅
        let name = peripheral.name ?? "Unknown"
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        
        print("===== 발견된 장치 =====")
        print("이름: \(name)")
        print("로컬 이름: \(localName)")
        print("UUID: \(peripheral.identifier)")
        print("RSSI: \(RSSI)")
        print("서비스 UUID: \(serviceUUIDs)")
        
        // Hasselblad X2D II 카메라 확인 - 정확한 이름 매칭
        let isHasselblad = name.contains("X2D") || 
                          localName.contains("X2D") || 
                          name.contains("100C") ||  // 시리얼 번호 패턴
                          serviceUUIDs.contains(CBUUID(string: "FFF0"))  // Hasselblad 서비스
        
        if isHasselblad {
            print("🎯 Hasselblad X2D II 카메라 발견!")
            print("카메라 이름: \(name)")
            print("서비스: \(serviceUUIDs)")
            
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredDevices.append(peripheral)
                DispatchQueue.main.async {
                    self.cameraInfo = "Hasselblad \(name) 발견됨!"
                    // 자동 연결 시도 제거 - 사용자가 선택하도록
                }
                // 자동 연결 제거
                // connectToDevice(peripheral)
                return
            }
        }
        
        // 제조사 ID로도 확인 (aa08 = Hasselblad)
        if let manufacturerData = manufacturerData, manufacturerData.count >= 2 {
            let companyID = manufacturerData[0..<2].hexEncodedString()
            if companyID == "aa08" {
                print("🎯 제조사 ID로 Hasselblad 확인!")
                if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                    discoveredDevices.append(peripheral)
                    DispatchQueue.main.async {
                        self.cameraInfo = "Hasselblad 카메라 발견됨!"
                    }
                    // 자동 연결 제거
                    // connectToDevice(peripheral)
                    return
                }
            }
        }
        
        // 제조사 데이터 분석
        if let manufacturerData = manufacturerData {
            print("제조사 데이터: \(manufacturerData.hexEncodedString())")
            
            // Hasselblad 제조사 ID 체크 (추정)
            if manufacturerData.count >= 2 {
                let companyID = manufacturerData[0..<2]
                print("제조사 ID: \(companyID.hexEncodedString())")
            }
        }
        
        // 모든 발견된 장치를 리스트에 추가
        if !allDiscoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            allDiscoveredDevices.append((peripheral: peripheral, name: name, rssi: RSSI))
            
            DispatchQueue.main.async {
                self.cameraInfo = "\(self.allDiscoveredDevices.count)개 장치 발견 (검색 중...)"
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Bluetooth 연결 성공: \(peripheral.name ?? "Unknown")")
        isBluetoothConnected = true
        cameraInfo = "Bluetooth 연결됨: \(peripheral.name ?? "Unknown")"
        
        // 서비스 검색 시작
        print("🔍 서비스 검색 시작...")
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ 연결 실패: \(error?.localizedDescription ?? "Unknown error")")
        isBluetoothConnected = false
        connectedPeripheral = nil
        
        let errorMessage = error?.localizedDescription ?? "알 수 없는 오류"
        cameraInfo = "연결 실패: \(errorMessage)"
        
        // 에러 상세 분석
        if let nsError = error as NSError? {
            print("에러 코드: \(nsError.code)")
            print("에러 도메인: \(nsError.domain)")
            
            switch nsError.code {
            case 14: // CBErrorConnectionTimeout
                cameraInfo = "연결 시간 초과 - 카메라를 다시 켜주세요"
            case 7: // CBErrorPeripheralDisconnected
                cameraInfo = "카메라 연결이 끊어졌습니다"
            case 13: // CBErrorNotConnected
                cameraInfo = "카메라가 연결되지 않았습니다"
            default:
                break
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔶 연결 해제: \(peripheral.name ?? "Unknown")")
        isBluetoothConnected = false
        isWiFiConnected = false
        connectedPeripheral = nil
        
        if let error = error {
            print("연결 해제 에러: \(error.localizedDescription)")
            cameraInfo = "예기치 않은 연결 해제"
        } else {
            cameraInfo = "연결 해제됨"
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothCameraManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ 서비스 검색 실패: \(error.localizedDescription)")
            cameraInfo = "서비스 검색 실패"
            return
        }
        
        guard let services = peripheral.services else {
            print("❌ 서비스가 없습니다")
            cameraInfo = "카메라 서비스를 찾을 수 없음"
            return
        }
        
        print("📋 발견된 서비스 (\(services.count)개):")
        var foundHasselbladService = false
        
        for service in services {
            print("- 서비스 UUID: \(service.uuid)")
            
            // Hasselblad 관련 서비스 확인
            if service.uuid.uuidString == "FFF0" {
                print("✅ Hasselblad 카메라 서비스 발견!")
                foundHasselbladService = true
                cameraInfo = "카메라 서비스 발견됨"
            }
            
            // 모든 특성 검색
            peripheral.discoverCharacteristics(nil, for: service)
        }
        
        if !foundHasselbladService {
            print("⚠️ Hasselblad 서비스를 찾지 못했지만 계속 진행합니다")
            // FFF0이 없어도 다른 서비스로 시도
            cameraInfo = "서비스 검색 중..."
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        print("서비스 \(service.uuid)의 특성:")
        for characteristic in characteristics {
            print("- 특성 UUID: \(characteristic.uuid)")
            print("  속성: \(characteristic.properties)")
            
            // FFF0 서비스의 특성 처리
            if service.uuid.uuidString == "FFF0" {
                switch characteristic.uuid.uuidString {
                case "FFF3":
                    // Wi-Fi 상태/제어 특성
                    print("📶 Wi-Fi 제어 특성 발견")
                    self.wifiCharacteristic = characteristic
                    
                    // FFF3는 나중에 처리 (다른 특성 먼저 읽기)
                    
                case "FFF4":
                    // 카메라 제어 특성
                    print("📷 카메라 제어 특성 발견")
                    self.cameraCharacteristic = characteristic
                    
                    // 상태 읽기
                    if characteristic.properties.contains(.read) {
                        peripheral.readValue(for: characteristic)
                    }
                    
                case "FFF5":
                    // 상태 특성 - 가장 먼저 읽기
                    print("ℹ️ 상태 특성 발견")
                    self.statusCharacteristic = characteristic
                    if characteristic.properties.contains(.read) {
                        peripheral.readValue(for: characteristic)
                    }
                    
                case "FFF7":
                    // 알림 특성 - 먼저 활성화
                    print("🔔 알림 특성 발견")
                    self.notifyCharacteristic = characteristic
                    if characteristic.properties.contains(.notify) {
                        print("🔔 FFF7 notify 활성화")
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                    if characteristic.properties.contains(.read) {
                        peripheral.readValue(for: characteristic)
                    }
                    
                default:
                    break
                }
            }
        }
        
        // 모든 특성 발견 완료 후 초기화 시작
        if service.uuid.uuidString == "FFF0" && !characteristicsReady {
            characteristicsReady = true
            // 2초 후 WiFi 초기화 시작 (다른 특성들이 준비될 시간)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.initializeWiFiSequence()
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            print("특성 \(characteristic.uuid) 값: \(data.hexEncodedString())")
            
            // FFF0 서비스의 특성 응답 처리
            if characteristic.service?.uuid.uuidString == "FFF0" {
                switch characteristic.uuid.uuidString {
                case "FFF3":
                    // Wi-Fi 상태 응답
                    print("📶 Wi-Fi 상태 응답: \(data.hexEncodedString())")
                    addDebugLog("WiFi 상태: \(data.hexEncodedString())")
                    
                    // 테스트 데이터인지 확인
                    if data == Data([0x11, 0x22, 0x33, 0x44]) {
                        print("⚠️ FFF3가 테스트 데이터 반환 - 초기화 중...")
                        addDebugLog("⚠️ FFF3 초기화 필요")
                        
                        // FFF3 리셋 시도
                        if !wifiInitialized {
                            resetWiFiCharacteristic()
                        }
                        return
                    }
                    
                    // Wi-Fi 상태 확인
                    if data == Data([0x01, 0x00]) {
                        print("✅ Wi-Fi가 이미 활성화되어 있습니다 (클라이언트 모드)")
                        DispatchQueue.main.async {
                            self.cameraInfo = "Wi-Fi 켜짐 - AP 모드 전환 필요"
                        }
                        
                        // AP 모드로 전환 시도 (writeWithoutResponse 사용)
                        print("🔄 AP 모드로 전환 시도...")
                        let apModeCommand = Data([0x04, 0x01, 0x00])  // AP_MODE_ON
                        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
                        peripheral.writeValue(apModeCommand, for: characteristic, type: writeType)
                        
                        // writeWithoutResponse인 경우 직접 상태 확인
                        if writeType == .withoutResponse {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                peripheral.readValue(for: characteristic)
                            }
                        }
                        
                        // AP 모드 전환 후 추가 설정
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.sendAPBroadcastCommands(peripheral: peripheral, characteristic: characteristic)
                        }
                        
                    } else if data == Data([0x04, 0x01, 0x00]) {
                        print("📡 AP 모드 활성화됨!")
                        addDebugLog("✅ AP 모드 활성화 성공!")
                        DispatchQueue.main.async {
                            self.cameraInfo = "카메라 Wi-Fi AP 모드 활성화"
                        }
                        
                        // AP 모드 활성화 후 추가 설정 필요
                        if let wifiChar = self.wifiCharacteristic {
                            self.sendAPBroadcastCommands(peripheral: peripheral, characteristic: wifiChar)
                        }
                        
                        // Wi-Fi 연결 시도
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            self.connectToWiFi()
                        }
                        
                    } else if data == Data([0x0a, 0x00, 0x01]) {
                        print("🎮 Remote Control 모드 활성화")
                        addDebugLog("Remote Control 모드 ON")
                        
                    } else if data == Data([0x08, 0x00, 0x00]) {
                        print("📝 WiFi 정보 응답 대기")
                        addDebugLog("WiFi 정보 요청 응답")
                        
                    } else if data == Data([0x02, 0x00, 0x01]) {
                        // 우리가 보낸 활성화 명령의 에코
                        print("📡 명령 에코 확인")
                    } else {
                        print("🔍 알 수 없는 Wi-Fi 상태: \(data.hexEncodedString())")
                        addDebugLog("알 수 없는 상태: \(data.hexEncodedString())")
                    }
                    
                case "FFF4":
                    // Wi-Fi 정보 응답
                    print("📡 Wi-Fi 정보 응답: \(data.hexEncodedString())")
                    
                    // SSID 정보 파싱 시도
                    if let ssidString = String(data: data, encoding: .utf8) {
                        print("📶 Wi-Fi SSID: \(ssidString)")
                        DispatchQueue.main.async {
                            self.cameraInfo = "Wi-Fi: \(ssidString)"
                        }
                    } else if data.count > 4 {
                        // 바이너리 형식일 수 있음
                        // 처음 몇 바이트는 헤더일 수 있음
                        let ssidData = data.dropFirst(2)
                        if let ssid = String(data: ssidData, encoding: .utf8) {
                            print("📶 Wi-Fi SSID (파싱): \(ssid)")
                        }
                    }
                    
                case "FFF5":
                    // 카메라 상태 응답
                    print("ℹ️ 카메라 상태: \(data.hexEncodedString())")
                    
                    // 상태 코드 분석
                    if data == Data([0x02, 0x00, 0x01]) {
                        print("카메라가 Wi-Fi 모드로 전환됨")
                    }
                    
                case "FFF7":
                    // 알림 데이터
                    print("🔔 FFF7 알림: \(data.hexEncodedString())")
                    addDebugLog("FFF7 notify: \(data.hexEncodedString())")
                    
                    // 알림 코드 분석
                    if data.first == 0x01 {
                        print("📢 Wi-Fi 준비 완료 알림")
                        DispatchQueue.main.async {
                            self.cameraInfo = "카메라 Wi-Fi 준비됨"
                        }
                        // WiFi 스캔 시작
                        self.scanForWiFiNetwork()
                    } else if data == Data([0x04, 0x01, 0x00]) {
                        print("📡 AP 모드 활성화 알림!")
                        self.addDebugLog("✅ AP 모드 활성화 알림")
                        // WiFi 스캔 시작
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.scanForWiFiNetwork()
                        }
                    }
                    
                default:
                    break
                }
            }
            
            // 응답 파싱 (문자열인 경우)
            if let string = String(data: data, encoding: .utf8) {
                print("문자열 값: \(string)")
                
                // Wi-Fi SSID 정보 확인
                if string.contains("X2D") || string.contains("Hasselblad") {
                    DispatchQueue.main.async {
                        self.cameraInfo = "Wi-Fi SSID: \(string)"
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ 쓰기 실패: \(error.localizedDescription)")
        } else {
            print("✅ 쓰기 성공: \(characteristic.uuid)")
            
            // Wi-Fi 제어 특성에 쓰기 성공한 경우
            if characteristic.uuid.uuidString == "FFF3" {
                print("Wi-Fi 활성화 명령 전송 완료")
                DispatchQueue.main.async {
                    self.cameraInfo = "Wi-Fi 활성화 요청 전송됨"
                }
                
                // 상태 확인을 위해 다시 읽기
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    // WiFi 상태 확인 (수동으로 설정 앱 열기 안내)
    private func checkWiFiStatus() {
        addDebugLog("📱 WiFi 설정 확인 필요")
        
        DispatchQueue.main.async {
            self.cameraInfo = """
            ⚠️ WiFi 수동 확인 필요:
            1. 설정 > WiFi 열기
            2. 'X2D' 또는 'Hasselblad' 검색
            3. 비밀번호 없이 연결
            """
        }
        
        // 알림으로도 사용자에게 안내
        addDebugLog("💡 iPhone 설정 > WiFi에서 카메라 네트워크를 확인하세요")
    }
    
    // WiFi 네트워크 스캔 (카메라 WiFi AP 찾기)
    private func scanForWiFiNetwork() {
        addDebugLog("📡 카메라 WiFi 네트워크 검색 중...")
        
        // 카메라 이름 기반 SSID 패턴
        let cameraName = connectedPeripheral?.name ?? "X2D II 100C 003635"
        
        // 가능한 SSID 패턴들 - 공백과 형식 유지 중요!
        let possibleSSIDs = [
            cameraName,  // 정확한 카메라 이름
            "X2D II 100C 003635",  // 확인된 SSID
            "X2D-II-100C-003635",  // 대시 버전
            "X2D_II_100C_003635",  // 언더스코어 버전
            "X2D",
            "Hasselblad"
        ]
        
        addDebugLog("🔍 검색할 SSID: \(cameraName)")
        
        // WiFi 자동 감지 로직
        detectAndConnectWiFi(possibleSSIDs: possibleSSIDs)
    }
    
    // WiFi 자동 감지 및 연결
    private func detectAndConnectWiFi(possibleSSIDs: [String]) {
        // NEHotspotConfiguration으로 각 SSID 시도
        var successFound = false
        
        for (index, ssid) in possibleSSIDs.enumerated() {
            // 딜레이를 두고 순차적으로 시도
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) { [weak self] in
                guard !successFound else { return }
                
                let configuration = NEHotspotConfiguration(ssid: ssid)
                configuration.joinOnce = false
                
                NEHotspotConfigurationManager.shared.apply(configuration) { error in
                    if error == nil {
                        successFound = true
                        self?.addDebugLog("✅ WiFi 발견 및 연결: \(ssid)")
                        DispatchQueue.main.async {
                            self?.currentSSID = ssid
                            self?.cameraInfo = "WiFi 연결됨: \(ssid)"
                            // 즉시 TCP 연결 시도
                            self?.tryConnection(hosts: ["192.168.2.1", "192.168.1.1", "192.168.0.1"], index: 0)
                        }
                    } else if error?.localizedDescription.contains("already associated") == true {
                        // 이미 연결되어 있음
                        successFound = true
                        self?.addDebugLog("ℹ️ 이미 연결됨: \(ssid)")
                        DispatchQueue.main.async {
                            self?.currentSSID = ssid
                            self?.cameraInfo = "WiFi 이미 연결됨: \(ssid)"
                            self?.tryConnection(hosts: ["192.168.2.1", "192.168.1.1", "192.168.0.1"], index: 0)
                        }
                    }
                }
            }
        }
        
        // 모든 시도 후에도 실패하면 수동 확인 안내
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(possibleSSIDs.count) * 0.5 + 2.0) { [weak self] in
            if !successFound {
                self?.checkWiFiStatus()
            }
        }
    }
}

// 디버그 로그 추가
extension BluetoothCameraManager {
    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"
        
        print(logMessage)
        
        DispatchQueue.main.async {
            self.debugLog += logMessage + "\n"
            // 로그가 너무 길어지지 않도록 제한
            let lines = self.debugLog.components(separatedBy: "\n")
            if lines.count > 100 {
                self.debugLog = lines.suffix(100).joined(separator: "\n")
            }
        }
    }
    
    // WiFi 정보 설정
    func setWiFiCredentials(ssid: String, password: String) {
        self.wifiSSID = ssid
        self.wifiPassword = password
        addDebugLog("WiFi 정보 저장: \(ssid)")
        
        // 바로 연결 시도
        if !ssid.isEmpty {
            connectToWiFiNetwork(ssid: ssid, password: password)
        }
    }
    
    // 카메라에서 WiFi 정보 읽기 시도
    func requestWiFiInfo() {
        guard let peripheral = connectedPeripheral,
              let characteristic = wifiCharacteristic else {
            addDebugLog("❌ WiFi 정보 요청 실패: 연결되지 않음")
            return
        }
        
        // WiFi 정보 요청 명령 전송
        let commands = [
            Data([0x03, 0x00, 0x01]), // GET_WIFI_INFO
            Data([0x07, 0x00, 0x00]), // GET_SSID
            Data([0x08, 0x00, 0x00])  // GET_PASSWORD
        ]
        
        for command in commands {
            addDebugLog("📡 WiFi 정보 요청: \(command.hexEncodedString())")
            peripheral.writeValue(command, for: characteristic, type: .withResponse)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
    
    // WiFi 초기화 시퀀스
    private func initializeWiFiSequence() {
        guard let peripheral = connectedPeripheral else { return }
        
        print("\n🔄 WiFi 초기화 시퀀스 시작")
        addDebugLog("🔄 WiFi 초기화 시퀀스 시작")
        
        // FFF5와 FFF4 먼저 읽기
        if let statusChar = statusCharacteristic {
            print("📖 FFF5 상태 읽기")
            peripheral.readValue(for: statusChar)
        }
        
        if let cameraChar = cameraCharacteristic {
            print("📖 FFF4 상태 읽기")
            peripheral.readValue(for: cameraChar)
        }
        
        // 1초 후 FFF3 읽기
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let wifiChar = self.wifiCharacteristic {
                print("📖 FFF3 초기 상태 읽기")
                peripheral.readValue(for: wifiChar)
            }
        }
    }
    
    // FFF3 리셋 및 초기화
    private func resetWiFiCharacteristic() {
        guard let peripheral = connectedPeripheral,
              let wifiChar = wifiCharacteristic else { return }
        
        print("\n🔧 FFF3 리셋 시작")
        addDebugLog("🔧 FFF3 리셋 시작")
        
        // writeWithoutResponse 사용
        let writeType: CBCharacteristicWriteType = wifiChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        
        // 리셋 명령들 시도
        let resetCommands: [(String, Data)] = [
            ("Clear", Data([0x00, 0x00, 0x00])),
            ("Reset", Data([0xFF, 0xFF, 0xFF])),
            ("Init", Data([0x00, 0x00, 0x01]))
        ]
        
        for (index, (name, command)) in resetCommands.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                print("🔧 \(name): \(command.hexEncodedString())")
                self.addDebugLog("리셋 - \(name): \(command.hexEncodedString())")
                peripheral.writeValue(command, for: wifiChar, type: writeType)
            }
        }
        
        // 리셋 후 WiFi 명령 전송
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.wifiInitialized = true
            self.sendWiFiCommands()
        }
    }
    
    // AP 브로드캐스트 명령 전송
    private func sendAPBroadcastCommands(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        print("\n📻 AP 브로드캐스트 설정 시작")
        addDebugLog("📻 AP 브로드캐스트 설정")
        
        // writeWithoutResponse 사용 여부 확인
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        print("🖊 Write Type: \(writeType == .withoutResponse ? "withoutResponse" : "withResponse")")
        
        // AP 모드 활성화 후 필요한 추가 명령들
        let broadcastCommands: [(String, Data)] = [
            // 채널 및 SSID 설정
            ("Set Channel 6", Data([0x05, 0x06, 0x00])),
            ("SSID Broadcast Enable", Data([0x0D, 0x01, 0x00])),
            
            // 브로드캐스트 및 서버 시작
            ("Broadcast ON", Data([0x0B, 0x01, 0x00])),
            ("Server Start", Data([0x0C, 0x01, 0x00])),
            
            // 연결 허용
            ("Accept Connections", Data([0x0E, 0x01, 0x00])),
            
            // Remote Control 활성화
            ("Remote Control ON", Data([0x0A, 0x01, 0x00])),
            
            // DHCP 서버
            ("DHCP Server ON", Data([0x09, 0x01, 0x00])),
            
            // 최종 활성화
            ("Final Activate", Data([0xFF, 0x01, 0x00]))
        ]
        
        for (index, (name, command)) in broadcastCommands.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                print("📻 \(name): \(command.hexEncodedString())")
                self.addDebugLog("\(name): \(command.hexEncodedString())")
                peripheral.writeValue(command, for: characteristic, type: writeType)
                
                // 각 명령 후 상태 읽기
                if index == broadcastCommands.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        peripheral.readValue(for: characteristic)
                    }
                }
            }
        }
        
        // 명령 완료 후 WiFi 스캔
        let totalDelay = Double(broadcastCommands.count) * 0.3 + 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            print("\n✅ AP 브로드캐스트 설정 완료")
            self.addDebugLog("✅ AP 브로드캐스트 설정 완료")
            
            // WiFi 네트워크 스캔
            self.scanForWiFiNetwork()
            
            // 추가 스캔
            for delay in [3.0, 6.0, 10.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.addDebugLog("📡 WiFi 재스캔 (\(Int(delay))초)")
                    self.scanForWiFiNetwork()
                    
                    if delay == 10.0 {
                        self.checkWiFiStatus()
                    }
                }
            }
        }
    }
    
    // WiFi 명령 전송
    private func sendWiFiCommands() {
        guard let peripheral = connectedPeripheral,
              let wifiChar = wifiCharacteristic else { return }
        
        print("\n📡 WiFi 활성화 명령 전송 시작")
        addDebugLog("📡 WiFi 활성화 명령 전송")
        
        // writeWithoutResponse 사용
        let writeType: CBCharacteristicWriteType = wifiChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        print("🖊 FFF3 Write Type: \(writeType == .withoutResponse ? "withoutResponse" : "withResponse")")
        
        // 개선된 명령 시퀀스
        let commands: [(String, Data)] = [
            // 기본 초기화
            ("WiFi Module Init", Data([0x00, 0x01, 0x00])),
            ("WiFi Power ON", Data([0x01, 0x01, 0x00])),
            ("WiFi Enable", Data([0x02, 0x01, 0x00])),
            
            // AP 모드 설정
            ("AP Mode", Data([0x04, 0x01, 0x00])),
            ("Channel 6", Data([0x05, 0x06, 0x00])),
            ("Max Clients", Data([0x06, 0x05, 0x00])),
            
            // SSID 설정 (카메라 이름 사용)
            ("SSID Enable", Data([0x07, 0x01, 0x00])),
            
            // 보안 설정 (없음)
            ("No Security", Data([0x08, 0x00, 0x00])),
            
            // 네트워크 설정
            ("DHCP Server", Data([0x09, 0x01, 0x00])),
            ("Remote Control", Data([0x0A, 0x01, 0x00])),
            
            // 브로드캐스트 활성화
            ("Broadcast ON", Data([0x0B, 0x01, 0x00])),
            ("Server Start", Data([0x0C, 0x01, 0x00])),
            ("SSID Visible", Data([0x0D, 0x01, 0x00])),
            
            // 연결 허용
            ("Accept Connections", Data([0x0E, 0x01, 0x00])),
            
            // Phocus 호환 모드
            ("Phocus Mode", Data([0x0F, 0x01, 0x00])),
            ("Protocol V2", Data([0x10, 0x02, 0x00])),
            
            // 활성화 완료
            ("Activate", Data([0xFF, 0x01, 0x00]))
        ]
        
        // 명령 순차 전송
        for (index, (name, command)) in commands.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                print("📡 \(name): \(command.hexEncodedString())")
                self.addDebugLog("\(name): \(command.hexEncodedString())")
                peripheral.writeValue(command, for: wifiChar, type: writeType)
            }
        }
        
        // 명령 전송 완료 후 WiFi 스캔
        let totalDelay = Double(commands.count) * 0.2 + 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            print("\n✅ WiFi 명령 전송 완료")
            self.addDebugLog("✅ WiFi 명령 전송 완료")
            
            // 상태 확인
            peripheral.readValue(for: wifiChar)
            
            // WiFi 네트워크 스캔 시작
            self.scanForWiFiNetwork()
            
            // 추가 스캔 예약
            for delay in [3.0, 6.0, 10.0, 15.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.addDebugLog("📡 WiFi 재스캔 (\(Int(delay))초)")
                    self.scanForWiFiNetwork()
                }
            }
        }
    }
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}