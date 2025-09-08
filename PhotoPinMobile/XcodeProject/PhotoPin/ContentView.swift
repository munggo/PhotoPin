import SwiftUI
import CoreLocation
import UIKit

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var bluetoothManager = BluetoothCameraManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var locationService = LocationService()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedTab = 0
    @State private var useBluetoothMode = true
    @State private var showWiFiSettings = false
    @State private var wifiSSID = ""
    @State private var wifiPassword = ""
    @State private var showDebugLog = false
    
    var body: some View {
        TabView {
            // 홈 화면
            VStack(spacing: 30) {
                Image(systemName: "camera.metering.matrix")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                
                Text("PhotoPin Mobile")
                    .font(.largeTitle)
                    .bold()
                
                HStack(spacing: 50) {
                    VStack {
                        Image(systemName: useBluetoothMode ? 
                              (bluetoothManager.isWiFiConnected ? "wifi" : "wifi.slash") :
                              (cameraManager.isConnected ? "wifi" : "wifi.slash"))
                            .font(.title)
                            .foregroundColor(useBluetoothMode ? 
                                           (bluetoothManager.isWiFiConnected ? .green : .gray) :
                                           (cameraManager.isConnected ? .green : .gray))
                        Text(useBluetoothMode ?
                            (bluetoothManager.isWiFiConnected ? "연결됨" : "미연결") :
                            (cameraManager.isConnected ? "연결됨" : "미연결"))
                            .font(.caption)
                    }
                    
                    VStack {
                        Image(systemName: locationManager.isTracking ? "location.fill" : "location")
                            .font(.title)
                            .foregroundColor(locationManager.isTracking ? .green : .gray)
                        Text(locationManager.isTracking ? "추적중" : "대기")
                            .font(.caption)
                    }
                }
                
                Text("촬영: \(cameraManager.photoCount)장")
                    .font(.title2)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            .tabItem {
                Label("홈", systemImage: "house.fill")
            }
            
            // 카메라 화면
            VStack(spacing: 30) {
                // 연결 모드 선택
                Picker("연결 모드", selection: $useBluetoothMode) {
                    Text("Bluetooth → Wi-Fi").tag(true)
                    Text("Wi-Fi 직접 연결").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                Image(systemName: useBluetoothMode ? "dot.radiowaves.left.and.right" : "wifi")
                    .font(.system(size: 60))
                    .foregroundColor(useBluetoothMode ? 
                                   (bluetoothManager.isWiFiConnected ? .green : .gray) :
                                   (cameraManager.isConnected ? .green : .gray))
                
                Text(useBluetoothMode ? bluetoothManager.cameraInfo : cameraManager.cameraInfo)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if useBluetoothMode {
                    // Bluetooth 모드
                    if !bluetoothManager.isBluetoothConnected {
                        VStack(spacing: 15) {
                            Text("Phocus 스타일 연결:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("1. 카메라 Bluetooth ON\n2. 자동으로 Wi-Fi 활성화\n3. 자동 연결")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                bluetoothManager.startScanning()
                            }) {
                                Text(bluetoothManager.isScanning ? "검색 중..." : "카메라 검색")
                                    .padding()
                                    .frame(width: 200)
                                    .background(bluetoothManager.isScanning ? Color.gray : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(bluetoothManager.isScanning)
                            
                            // Hasselblad 카메라 우선 표시
                            if !bluetoothManager.discoveredDevices.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("🎯 Hasselblad 카메라:")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.green)
                                    
                                    ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                                        Button(action: {
                                            bluetoothManager.connectToDevice(device)
                                        }) {
                                            HStack {
                                                Image(systemName: "camera.fill")
                                                    .foregroundColor(.green)
                                                Text(device.name ?? "Hasselblad X2D II")
                                                    .font(.body)
                                                    .bold()
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.gray)
                                            }
                                            .padding()
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(10)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // 기타 발견된 장치 목록
                            if !bluetoothManager.allDiscoveredDevices.isEmpty && bluetoothManager.discoveredDevices.isEmpty {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("발견된 장치:")
                                        .font(.caption)
                                        .bold()
                                    
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 3) {
                                            ForEach(bluetoothManager.allDiscoveredDevices, id: \.peripheral.identifier) { device in
                                                Button(action: {
                                                    bluetoothManager.connectToDevice(device.peripheral)
                                                }) {
                                                    HStack {
                                                        Text(device.name)
                                                            .font(.caption2)
                                                        Spacer()
                                                        Text("RSSI: \(device.rssi)")
                                                            .font(.caption2)
                                                            .foregroundColor(.gray)
                                                    }
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 5)
                                                    .background(Color.gray.opacity(0.1))
                                                    .cornerRadius(5)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 150)
                                }
                                .padding(.horizontal)
                            }
                            
                            if bluetoothManager.isBluetoothConnected && !bluetoothManager.isWiFiConnected {
                                VStack(spacing: 15) {
                                    ProgressView("Wi-Fi 활성화 중...")
                                        .padding()
                                    
                                    Text("📶 카메라 Wi-Fi 설정")
                                        .font(.headline)
                                    
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("카메라 화면에서:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("1. Menu → Wi-Fi")
                                            .font(.caption2)
                                        Text("2. Remote Control 선택")
                                            .font(.caption2)
                                        Text("3. 표시되는 SSID 확인")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    
                                    // WiFi SSID 입력 (비밀번호 불필요)
                                    VStack(spacing: 10) {
                                        TextField("WiFi SSID (예: X2D-II-100C-003635)", text: $wifiSSID)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.none)
                                        
                                        Text("💡 카메라 WiFi는 비밀번호가 없습니다")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        
                                        Button(action: {
                                            bluetoothManager.setWiFiCredentials(ssid: wifiSSID, password: "")
                                        }) {
                                            Text("자동 연결 시도")
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(!wifiSSID.isEmpty ? Color.green : Color.gray)
                                                .foregroundColor(.white)
                                                .cornerRadius(10)
                                        }
                                        .disabled(wifiSSID.isEmpty)
                                    }
                                    .padding(.horizontal)
                                    
                                    // 수동 설정 열기 버튼
                                    Button(action: {
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        Text("수동으로 설정 앱 열기")
                                            .font(.caption)
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                }
                                .padding()
                            }
                        }
                    } else if bluetoothManager.isWiFiConnected {
                        Text("Hasselblad X2D II")
                            .font(.title2)
                        
                        Button(action: {
                            bluetoothManager.capturePhoto(with: locationManager.currentLocation)
                            alertMessage = "촬영 완료!\nGPS: \(locationManager.currentLocation != nil ? "포함됨" : "없음")"
                            showAlert = true
                        }) {
                            Text("📸 촬영")
                                .padding()
                                .frame(width: 200)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            bluetoothManager.disconnect()
                        }) {
                            Text("연결 해제")
                                .padding()
                                .frame(width: 200)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                } else {
                    // Wi-Fi 직접 연결 모드
                    if !cameraManager.isConnected {
                        VStack(spacing: 15) {
                            Text("카메라 Wi-Fi 연결 방법:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("1. 카메라 Wi-Fi 켜기\n2. iPhone Wi-Fi 설정에서 카메라 선택\n3. 아래 버튼 클릭")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                cameraManager.connectToCamera()
                            }) {
                                Text("카메라 연결")
                                    .padding()
                                    .frame(width: 200)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    } else {
                        Text("Hasselblad X2D")
                            .font(.title2)
                        
                        Button(action: {
                            cameraManager.capturePhoto(with: locationManager.currentLocation)
                            alertMessage = "촬영 완료!\nGPS: \(locationManager.currentLocation != nil ? "포함됨" : "없음")"
                            showAlert = true
                        }) {
                            Text("📸 촬영")
                                .padding()
                                .frame(width: 200)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            cameraManager.disconnect()
                        }) {
                            Text("연결 해제")
                                .padding()
                                .frame(width: 200)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .alert("알림", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .tabItem {
                Label("카메라", systemImage: "camera.fill")
            }
            
            // GPS 화면
            VStack(spacing: 30) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(locationManager.isTracking ? .green : .gray)
                
                Text(locationManager.isTracking ? "GPS 추적 중..." : "GPS 대기")
                    .font(.title2)
                
                Text(locationManager.locationString)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                // 위치 전송 상태
                if locationService.isTransmitting {
                    VStack(spacing: 10) {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("카메라로 전송 중")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Text("연결: \(locationService.connectionType)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(locationService.transmissionStatus)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if locationManager.authorizationStatus == .notDetermined {
                    Button(action: {
                        locationManager.requestPermission()
                    }) {
                        Text("위치 권한 요청")
                            .padding()
                            .frame(width: 200)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else {
                    VStack(spacing: 15) {
                        Button(action: {
                            if locationManager.isTracking {
                                locationManager.stopTracking()
                            } else {
                                locationManager.startTracking()
                            }
                        }) {
                            Text(locationManager.isTracking ? "GPS 중지" : "GPS 시작")
                                .padding()
                                .frame(width: 200)
                                .background(locationManager.isTracking ? Color.red : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        // 카메라로 위치 전송 버튼
                        Button(action: {
                            if locationService.isTransmitting {
                                locationService.stopTransmitting()
                            } else {
                                // WiFi 연결 상태 확인
                                if bluetoothManager.isWiFiConnected || cameraManager.isConnected {
                                    locationService.startTransmitting()
                                } else {
                                    alertMessage = "먼저 카메라 WiFi에 연결하세요"
                                    showAlert = true
                                }
                            }
                        }) {
                            Text(locationService.isTransmitting ? "전송 중지" : "카메라로 전송")
                                .padding()
                                .frame(width: 200)
                                .background(locationService.isTransmitting ? Color.orange : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(!locationManager.isTracking)
                    }
                }
            }
            .alert("알림", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .tabItem {
                Label("GPS", systemImage: "location.fill")
            }
            
            // 디버그 화면
            VStack {
                HStack {
                    Text("디버그 로그")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        bluetoothManager.debugLog = ""
                    }) {
                        Text("클리어")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(5)
                    }
                }
                .padding()
                
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bluetoothManager.debugLog.isEmpty ? "로그가 비어 있습니다" : bluetoothManager.debugLog)
                                .font(.system(size: 10, design: .monospaced))
                                .padding()
                                .id("bottom")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: bluetoothManager.debugLog) { _ in
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // WiFi 상태 표시
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("현재 WiFi SSID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(bluetoothManager.wifiSSID.isEmpty ? "없음" : bluetoothManager.wifiSSID)
                            .font(.caption)
                            .bold()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("연결 상태:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Circle()
                                .fill(bluetoothManager.isWiFiConnected ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(bluetoothManager.isWiFiConnected ? "연결됨" : "미연결")
                                .font(.caption)
                                .bold()
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // 수동 WiFi 정보 요청 버튼
                Button(action: {
                    bluetoothManager.requestWiFiInfo()
                }) {
                    Text("카메라에서 WiFi 정보 요청")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(bluetoothManager.isBluetoothConnected ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!bluetoothManager.isBluetoothConnected)
                .padding(.horizontal)
            }
            .tabItem {
                Label("디버그", systemImage: "ant.fill")
            }
        }
    }
}