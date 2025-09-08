import Foundation
import CoreLocation
import Network

// 위치 정보 전송 서비스
class LocationService: NSObject, ObservableObject {
    @Published var isTransmitting = false
    @Published var lastLocation: CLLocation?
    @Published var transmissionStatus = ""
    @Published var connectionType = "검색 중..."
    
    private var locationManager: CLLocationManager!
    private var tcpConnection: NWConnection?
    private var timer: Timer?
    private var urlSession: URLSession!
    
    // WiFi 비밀번호 (Phocus가 자동으로 처리하지만 필요시 사용)
    private let wifiPassword = "ejTDqJAS9beL"
    
    // 카메라 연결 정보
    private let cameraHost = "192.168.2.1"
    private var discoveredPorts: [Int] = []
    
    override init() {
        super.init()
        setupLocationManager()
        setupURLSession()
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        urlSession = URLSession(configuration: config)
    }
    
    // 위치 정보 전송 시작 - 자동으로 올바른 프로토콜 탐색
    func startTransmitting() {
        print("📍 위치 정보 전송 시작")
        transmissionStatus = "카메라 서비스 검색 중..."
        
        // 위치 업데이트 시작
        locationManager.startUpdatingLocation()
        
        // 카메라 서비스 탐색
        discoverCameraServices()
    }
    
    // 카메라가 제공하는 서비스 탐색
    private func discoverCameraServices() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            // 주요 포트 스캔
            let portsToCheck = [80, 8080, 443, 8443, 15740, 9000, 5000]
            var foundPorts: [Int] = []
            
            for port in portsToCheck {
                if self.checkPort(port) {
                    foundPorts.append(port)
                    print("✅ 포트 \(port) 발견")
                }
            }
            
            self.discoveredPorts = foundPorts
            
            DispatchQueue.main.async {
                if foundPorts.contains(80) || foundPorts.contains(8080) {
                    self.connectionType = "HTTP"
                    self.transmissionStatus = "HTTP 서비스 발견"
                    self.startHTTPTransmission()
                } else if foundPorts.contains(15740) {
                    self.connectionType = "PTP/IP"
                    self.transmissionStatus = "PTP/IP 서비스 발견"
                    self.startPTPTransmission()
                } else if !foundPorts.isEmpty {
                    self.connectionType = "TCP"
                    self.transmissionStatus = "TCP 서비스 발견"
                    self.startTCPTransmission(port: UInt16(foundPorts.first!))
                } else {
                    self.transmissionStatus = "서비스를 찾을 수 없음"
                    self.connectionType = "없음"
                }
            }
        }
    }
    
    // 포트 확인
    private func checkPort(_ port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        if sock < 0 { return false }
        defer { close(sock) }
        
        var addr = sockaddr_in()
        addr.sin_family = UInt8(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        inet_pton(AF_INET, cameraHost, &addr.sin_addr)
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, UInt32(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return result == 0
    }
    
    // HTTP 기반 위치 전송
    private func startHTTPTransmission() {
        print("🌐 HTTP 기반 위치 전송 시작")
        isTransmitting = true
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendLocationViaHTTP()
        }
    }
    
    // HTTP로 위치 데이터 전송
    private func sendLocationViaHTTP() {
        guard let location = lastLocation else { return }
        
        // 다양한 엔드포인트 시도
        let endpoints = ["/gps", "/location", "/api/location", "/geotag", "/metadata"]
        let port = discoveredPorts.contains(80) ? 80 : 8080
        
        for endpoint in endpoints {
            let urlString = "http://\(cameraHost):\(port)\(endpoint)"
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let locationData: [String: Any] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "altitude": location.altitude,
                "accuracy": location.horizontalAccuracy,
                "timestamp": ISO8601DateFormatter().string(from: location.timestamp)
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: locationData)
                
                urlSession.dataTask(with: request) { [weak self] data, response, error in
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode < 400 {
                            print("✅ \(endpoint): \(httpResponse.statusCode)")
                            DispatchQueue.main.async {
                                self?.transmissionStatus = "위치 전송 중 (\(endpoint))"
                            }
                        }
                    }
                }.resume()
            } catch {
                print("❌ JSON 생성 실패: \(error)")
            }
        }
    }
    
    // PTP/IP 기반 위치 전송
    private func startPTPTransmission() {
        print("📷 PTP/IP 기반 위치 전송 시작")
        // PTP/IP는 복잡한 프로토콜이므로 기본 TCP로 시도
        startTCPTransmission(port: 15740)
    }
    
    // TCP 기반 위치 전송 (기존 방식)
    private func startTCPTransmission(port: UInt16 = 80) {
        print("📡 TCP 기반 위치 전송 시작: \(cameraHost):\(port)")
        
        let host = NWEndpoint.Host(cameraHost)
        let tcpPort = NWEndpoint.Port(integerLiteral: port)
        
        tcpConnection = NWConnection(host: host, port: tcpPort, using: .tcp)
        tcpConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ 카메라 연결 준비됨")
                self?.transmissionStatus = "카메라 연결됨 (TCP)"
                self?.isTransmitting = true
                self?.startLocationTimer()
                
            case .failed(let error):
                print("❌ 연결 실패: \(error)")
                self?.transmissionStatus = "연결 실패"
                self?.isTransmitting = false
                
            default:
                break
            }
        }
        
        tcpConnection?.start(queue: .main)
    }
    
    // 주기적으로 위치 전송
    private func startLocationTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendCurrentLocation()
        }
    }
    
    // 현재 위치 전송 (TCP)
    private func sendCurrentLocation() {
        guard let location = lastLocation,
              let connection = tcpConnection else { return }
        
        // Hasselblad 프로토콜에 맞는 위치 데이터 생성
        let locationData = createLocationPacket(location)
        
        connection.send(content: locationData, completion: .contentProcessed { error in
            if let error = error {
                print("❌ 전송 실패: \(error)")
            } else {
                print("📡 위치 전송: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            }
        })
    }
    
    // Hasselblad 위치 패킷 생성
    private func createLocationPacket(_ location: CLLocation) -> Data {
        // 프로토콜 형식 (추정)
        // Header(4) + Timestamp(8) + Latitude(8) + Longitude(8) + Altitude(4) + Accuracy(4)
        
        var packet = Data()
        
        // 헤더 (매직 넘버)
        packet.append(contentsOf: [0x48, 0x42, 0x4C, 0x44]) // "HBLD"
        
        // 타임스탬프
        let timestamp = location.timestamp.timeIntervalSince1970
        packet.append(contentsOf: withUnsafeBytes(of: timestamp.bitPattern) { Array($0) })
        
        // 위도
        let latitude = location.coordinate.latitude
        packet.append(contentsOf: withUnsafeBytes(of: latitude.bitPattern) { Array($0) })
        
        // 경도
        let longitude = location.coordinate.longitude
        packet.append(contentsOf: withUnsafeBytes(of: longitude.bitPattern) { Array($0) })
        
        // 고도
        let altitude = Float(location.altitude)
        packet.append(contentsOf: withUnsafeBytes(of: altitude.bitPattern) { Array($0) })
        
        // 정확도
        let accuracy = Float(location.horizontalAccuracy)
        packet.append(contentsOf: withUnsafeBytes(of: accuracy.bitPattern) { Array($0) })
        
        return packet
    }
    
    // XMP 형식으로 위치 데이터 생성 (대안)
    private func createXMPLocationData(_ location: CLLocation) -> String {
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: location.timestamp)
        
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about=""
                    xmlns:exif="http://ns.adobe.com/exif/1.0/"
                    xmlns:xmp="http://ns.adobe.com/xap/1.0/">
                    <exif:GPSLatitude>\(location.coordinate.latitude)</exif:GPSLatitude>
                    <exif:GPSLongitude>\(location.coordinate.longitude)</exif:GPSLongitude>
                    <exif:GPSAltitude>\(location.altitude)</exif:GPSAltitude>
                    <exif:GPSTimeStamp>\(dateString)</exif:GPSTimeStamp>
                    <xmp:CreateDate>\(dateString)</xmp:CreateDate>
                </rdf:Description>
            </rdf:RDF>
        </x:xmpmeta>
        """
    }
    
    // 전송 중지
    func stopTransmitting() {
        print("⏹ 위치 전송 중지")
        isTransmitting = false
        timer?.invalidate()
        timer = nil
        tcpConnection?.cancel()
        tcpConnection = nil
        locationManager.stopUpdatingLocation()
        transmissionStatus = "전송 중지됨"
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        
        DispatchQueue.main.async {
            self.transmissionStatus = String(format: "위치: %.6f, %.6f", 
                                            location.coordinate.latitude,
                                            location.coordinate.longitude)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 위치 오류: \(error)")
        transmissionStatus = "위치 오류: \(error.localizedDescription)"
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ 위치 권한 승인됨")
        case .denied, .restricted:
            print("❌ 위치 권한 거부됨")
            transmissionStatus = "위치 권한이 필요합니다"
        default:
            break
        }
    }
}