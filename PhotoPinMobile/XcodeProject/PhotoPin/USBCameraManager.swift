import Foundation
import CoreLocation
import ExternalAccessory

class USBCameraManager: ObservableObject {
    @Published var isConnected = false
    @Published var cameraInfo = "USB 연결 대기중..."
    @Published var photoCount = 0
    
    // USB/PTP 통신을 위한 설정
    private var session: EASession?
    private let protocolString = "com.hasselblad.protocol" // 실제 프로토콜 확인 필요
    
    init() {
        // USB 액세서리 알림 등록
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryDidConnect),
            name: .EAAccessoryDidConnect,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryDidDisconnect),
            name: .EAAccessoryDidDisconnect,
            object: nil
        )
        
        checkForConnectedCamera()
    }
    
    func checkForConnectedCamera() {
        // 연결된 액세서리 확인
        let accessories = EAAccessoryManager.shared().connectedAccessories
        
        for accessory in accessories {
            print("발견된 액세서리: \(accessory.name)")
            print("제조사: \(accessory.manufacturer)")
            print("모델: \(accessory.modelNumber)")
            print("프로토콜: \(accessory.protocolStrings)")
            
            if accessory.manufacturer.contains("Hasselblad") ||
               accessory.name.contains("X2D") {
                connectToCamera(accessory)
                break
            }
        }
    }
    
    @objc private func accessoryDidConnect(_ notification: Notification) {
        DispatchQueue.main.async {
            self.checkForConnectedCamera()
        }
    }
    
    @objc private func accessoryDidDisconnect(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.cameraInfo = "카메라 연결 해제됨"
            self.session = nil
        }
    }
    
    private func connectToCamera(_ accessory: EAAccessory) {
        // 세션 생성
        if let protocol = accessory.protocolStrings.first {
            session = EASession(accessory: accessory, forProtocol: protocol)
            
            if let session = session {
                session.inputStream?.delegate = self
                session.outputStream?.delegate = self
                
                session.inputStream?.schedule(in: .current, forMode: .default)
                session.outputStream?.schedule(in: .current, forMode: .default)
                
                session.inputStream?.open()
                session.outputStream?.open()
                
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.cameraInfo = "Hasselblad X2D II 연결됨 (USB)"
                }
            }
        }
    }
    
    func capturePhoto(with location: CLLocation?) {
        // PTP 촬영 명령 전송
        guard let outputStream = session?.outputStream,
              outputStream.hasSpaceAvailable else {
            print("출력 스트림 사용 불가")
            return
        }
        
        // PTP InitiateCapture 명령 (예시)
        let captureCommand: [UInt8] = [
            0x10, 0x00, 0x00, 0x00,  // 길이
            0x01, 0x00,              // 타입
            0x0E, 0x10,              // 코드 (InitiateCapture)
            0x01, 0x00, 0x00, 0x00,  // 트랜잭션 ID
            0x00, 0x00, 0x00, 0x00   // 파라미터
        ]
        
        let bytesWritten = outputStream.write(captureCommand, maxLength: captureCommand.count)
        
        if bytesWritten > 0 {
            DispatchQueue.main.async {
                self.photoCount += 1
                
                // GPS 데이터가 있으면 XMP 파일 생성
                if let location = location {
                    self.createXMPForLastPhoto(location: location)
                }
            }
        }
    }
    
    private func createXMPForLastPhoto(location: CLLocation) {
        let xmpContent = generateXMP(for: location)
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let xmpPath = documentsPath.appendingPathComponent("IMG_\(photoCount).xmp")
        
        do {
            try xmpContent.write(to: xmpPath, atomically: true, encoding: .utf8)
            print("XMP 파일 생성: \(xmpPath)")
            
            // 나중에 카메라로 XMP 전송
            sendXMPToCamera(xmpPath: xmpPath)
        } catch {
            print("XMP 파일 생성 실패: \(error)")
        }
    }
    
    private func sendXMPToCamera(xmpPath: URL) {
        // PTP SendObjectInfo와 SendObject 명령으로 XMP 파일 전송
        // 실제 구현은 카메라 프로토콜 문서 필요
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
}

// Stream Delegate
extension USBCameraManager: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            handleIncomingData(from: aStream as! InputStream)
        case .hasSpaceAvailable:
            print("출력 스트림 준비됨")
        case .errorOccurred:
            print("스트림 에러 발생")
        case .endEncountered:
            print("스트림 종료")
        default:
            break
        }
    }
    
    private func handleIncomingData(from inputStream: InputStream) {
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                // PTP 응답 파싱
                let data = Data(bytes: buffer, count: bytesRead)
                print("카메라 응답: \(data.hexEncodedString())")
            }
        }
    }
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}