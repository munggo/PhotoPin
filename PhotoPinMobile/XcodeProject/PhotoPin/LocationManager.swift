import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var isTracking = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationString = "위치 대기중..."
    
    private let locationManager = CLLocationManager()
    private var locationHistory: [CLLocation] = []
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0  // 5미터 이동 시 업데이트
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .other
    }
    
    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startTracking() {
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
            isTracking = true
        }
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        isTracking = false
    }
    
    // CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startTracking()
        case .denied, .restricted:
            locationString = "위치 권한이 거부됨"
        case .notDetermined:
            requestPermission()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        locationHistory.append(location)
        
        // 최근 100개 위치만 유지 (메모리 관리)
        if locationHistory.count > 100 {
            locationHistory.removeFirst()
        }
        
        // UI 업데이트
        let lat = String(format: "%.4f", location.coordinate.latitude)
        let lon = String(format: "%.4f", location.coordinate.longitude)
        let alt = String(format: "%.1f", location.altitude)
        
        locationString = "위도: \(lat)°\n경도: \(lon)°\n고도: \(alt)m"
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("위치 오류: \(error.localizedDescription)")
        locationString = "위치 오류: \(error.localizedDescription)"
    }
    
    // 사진 촬영 시간과 가장 가까운 위치 찾기
    func getLocationForPhoto(at timestamp: Date) -> CLLocation? {
        // 촬영 시간과 가장 가까운 GPS 위치 찾기
        var closestLocation: CLLocation?
        var minTimeDiff = TimeInterval.greatestFiniteMagnitude
        
        for location in locationHistory {
            let timeDiff = abs(location.timestamp.timeIntervalSince(timestamp))
            if timeDiff < minTimeDiff && timeDiff < 60 { // 60초 이내
                minTimeDiff = timeDiff
                closestLocation = location
            }
        }
        
        return closestLocation
    }
    
    // 디버깅용 위치 기록 내보내기
    func exportLocationHistory() -> String {
        var csv = "Timestamp,Latitude,Longitude,Altitude,Speed,Course\n"
        
        for location in locationHistory {
            csv += "\(location.timestamp),"
            csv += "\(location.coordinate.latitude),"
            csv += "\(location.coordinate.longitude),"
            csv += "\(location.altitude),"
            csv += "\(location.speed),"
            csv += "\(location.course)\n"
        }
        
        return csv
    }
}