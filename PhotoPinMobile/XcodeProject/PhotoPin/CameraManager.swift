import Foundation
import Network
import CoreLocation

class CameraManager: ObservableObject {
    @Published var isConnected = false
    @Published var cameraInfo = "연결 대기중..."
    @Published var lastPhotoPath: String?
    @Published var photoCount = 0
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "camera.network.queue")
    
    // Hasselblad X2D의 실제 IP (카메라 Wi-Fi 연결 시)
    private let cameraHost = "192.168.1.1"  // 카메라 기본 IP (실제 값으로 변경 필요)
    private let cameraPort: UInt16 = 80
    
    func connectToCamera() {
        // 네트워크 연결 설정
        let host = NWEndpoint.Host(cameraHost)
        let port = NWEndpoint.Port(rawValue: cameraPort)!
        
        connection = NWConnection(host: host, port: port, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.cameraInfo = "Hasselblad X2D 연결됨"
                    self?.getCameraStatus()
                case .failed(let error):
                    self?.isConnected = false
                    self?.cameraInfo = "연결 실패: \(error.localizedDescription)"
                case .waiting:
                    self?.cameraInfo = "연결 대기중..."
                default:
                    break
                }
            }
        }
        
        connection?.start(queue: queue)
    }
    
    func getCameraStatus() {
        // Hasselblad API 상태 요청
        let request = """
        GET /api/status HTTP/1.1\r
        Host: \(cameraHost)\r
        Connection: keep-alive\r
        \r
        """
        
        let data = request.data(using: .utf8)!
        connection?.send(content: data, completion: .contentProcessed { _ in
            print("상태 요청 전송됨")
        })
        
        // 응답 수신
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                let response = String(data: data, encoding: .utf8) ?? ""
                print("카메라 응답: \(response)")
                
                DispatchQueue.main.async {
                    // 응답 파싱
                    if response.contains("200 OK") {
                        self.cameraInfo = "Hasselblad X2D - 준비됨"
                    }
                }
            }
        }
    }
    
    func capturePhoto(with location: CLLocation?) {
        // 사진 촬영 명령
        let captureCommand = """
        POST /api/capture HTTP/1.1\r
        Host: \(cameraHost)\r
        Content-Type: application/json\r
        Content-Length: 2\r
        \r
        {}
        """
        
        let data = captureCommand.data(using: .utf8)!
        connection?.send(content: data, completion: .contentProcessed { _ in
            DispatchQueue.main.async {
                self.photoCount += 1
                
                // GPS 데이터가 있으면 XMP 파일 생성
                if let location = location {
                    self.createXMPForLastPhoto(location: location)
                }
            }
        })
    }
    
    private func createXMPForLastPhoto(location: CLLocation) {
        // XMP 파일 생성 로직
        let xmpContent = generateXMP(for: location)
        
        // 파일 저장 (나중에 카메라로 전송)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let xmpPath = documentsPath.appendingPathComponent("IMG_\(photoCount).xmp")
        
        do {
            try xmpContent.write(to: xmpPath, atomically: true, encoding: .utf8)
            print("XMP 파일 생성: \(xmpPath)")
        } catch {
            print("XMP 파일 생성 실패: \(error)")
        }
    }
    
    private func generateXMP(for location: CLLocation) -> String {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let alt = location.altitude
        
        let latRef = lat >= 0 ? "N" : "S"
        let lonRef = lon >= 0 ? "E" : "W"
        
        let latDegrees = Int(abs(lat))
        let latMinutes = Int((abs(lat) - Double(latDegrees)) * 60)
        let latSeconds = ((abs(lat) - Double(latDegrees)) * 60 - Double(latMinutes)) * 60
        
        let lonDegrees = Int(abs(lon))
        let lonMinutes = Int((abs(lon) - Double(lonDegrees)) * 60)
        let lonSeconds = ((abs(lon) - Double(lonDegrees)) * 60 - Double(lonMinutes)) * 60
        
        return """
        <?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
         <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about=""
            xmlns:exif="http://ns.adobe.com/exif/1.0/">
           <exif:GPSLatitude>\(latDegrees),\(latMinutes),\(String(format: "%.2f", latSeconds))\(latRef)</exif:GPSLatitude>
           <exif:GPSLongitude>\(lonDegrees),\(lonMinutes),\(String(format: "%.2f", lonSeconds))\(lonRef)</exif:GPSLongitude>
           <exif:GPSAltitude>\(String(format: "%.1f", alt))</exif:GPSAltitude>
           <exif:GPSAltitudeRef>\(alt >= 0 ? "0" : "1")</exif:GPSAltitudeRef>
           <exif:GPSTimeStamp>\(ISO8601DateFormatter().string(from: location.timestamp))</exif:GPSTimeStamp>
          </rdf:Description>
         </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
        """
    }
    
    func disconnect() {
        connection?.cancel()
        isConnected = false
        cameraInfo = "연결 해제됨"
    }
}