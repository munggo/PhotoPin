import SwiftUI
import UniformTypeIdentifiers
import Combine

@main
struct PhotoPinApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 650)
                .fixedSize()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("PhotoPin 정보") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "PhotoPin",
                            .applicationVersion: "1.0.0"
                        ]
                    )
                }
            }
        }
    }
}

// MARK: - View Model / 뷰 모델
class GeoTagViewModel: ObservableObject {
    @Published var gpxFile: URL?
    @Published var targetFolder: URL?
    @Published var processingMode = ProcessingMode.auto
    @Published var timezoneOffset = "+09:00"
    @Published var maxInterpolation = 1800
    @Published var maxExtrapolation = 18000
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var statusMessage = "준비"
    @Published var logMessages: [String] = []
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var photoCount = 0
    
    enum ProcessingMode: String, CaseIterable {
        case auto = "Auto"
        case sidecar = "Sidecar"
        case embed = "Embed"
        
        var description: String {
            switch self {
            case .auto: return "자동 (RAW→XMP, 이미지→Embed)"
            case .sidecar: return "XMP 사이드카 (모든 파일)"
            case .embed: return "직접 임베드 (원본 수정)"
            }
        }
        
        var icon: String {
            switch self {
            case .auto: return "wand.and.stars"
            case .sidecar: return "doc.badge.plus"
            case .embed: return "square.and.pencil"
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var activeTasks: [Process] = []
    
    var canStartProcessing: Bool {
        gpxFile != nil && targetFolder != nil && !isProcessing
    }
    
    func selectGPXFile() {
        let panel = NSOpenPanel()
        panel.title = "GPX 파일 선택"
        panel.message = "GPS 트랙이 포함된 GPX 파일을 선택하세요"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "gpx") ?? .xml]
        
        if panel.runModal() == .OK {
            gpxFile = panel.url
            addLog("GPX 파일 선택: \(panel.url?.lastPathComponent ?? "")")
            
            // Auto-detect timezone from GPX file / GPX 파일에서 시간대 정보 자동 감지
            if let url = panel.url {
                detectTimezoneFromGPX(url)
            }
        }
    }
    
    private func detectTimezoneFromGPX(_ url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            
            // Find TZ comment in GPX file (e.g., <!-- TZ: 32400 -->) / GPX 파일에서 TZ 주석 찾기 (예: <!-- TZ: 32400 -->)
            if let tzRange = content.range(of: "<!-- TZ: ([+-]?\\d+) -->", options: .regularExpression) {
                let tzString = String(content[tzRange])
                // Extract numeric part / 숫자 부분 추출
                let pattern = try? NSRegularExpression(pattern: "([+-]?\\d+)")
                if let match = pattern?.firstMatch(in: tzString, range: NSRange(tzString.startIndex..., in: tzString)) {
                    let offsetRange = Range(match.range(at: 1), in: tzString)!
                    let offsetSeconds = Int(tzString[offsetRange]) ?? 0
                    let hours = offsetSeconds / 3600
                    let minutes = abs(offsetSeconds % 3600) / 60
                    
                    let sign = hours >= 0 ? "+" : ""
                    let newOffset = String(format: "%@%02d:%02d", sign, abs(hours), minutes)
                    
                    if newOffset != timezoneOffset {
                        timezoneOffset = newOffset
                        addLog("✨ GPX에서 시간대 자동 감지: \(newOffset)")
                        
                        // Display timezone name / 시간대 이름 표시
                        let timezoneName = getTimezoneName(hours: hours)
                        if !timezoneName.isEmpty {
                            addLog("   지역: \(timezoneName)")
                        }
                    }
                }
            } else {
                // Check first time info in GPX file / GPX 파일의 첫 번째 시간 정보 확인
                if content.contains("<time>") && content.contains("Z</time>") {
                    addLog("ℹ️ GPX 파일은 UTC 시간을 사용합니다")
                    addLog("   카메라가 현지 시간인 경우 타임존 오프셋을 설정하세요")
                }
            }
        } catch {
            addLog("GPX 파일 분석 실패: \(error.localizedDescription)")
        }
    }
    
    private func getTimezoneName(hours: Int) -> String {
        switch hours {
        case -11: return "미국 하와이"
        case -8: return "미국 서부 (PST)"
        case -7: return "미국 산악 (MST)"
        case -6: return "미국 중부 (CST)"
        case -5: return "미국 동부 (EST)"
        case -3: return "브라질"
        case 0: return "영국 (GMT/UTC)"
        case 1: return "유럽 중부 (파리, 베를린)"
        case 2: return "유럽 동부 (아테네)"
        case 3: return "러시아 모스크바"
        case 4: return "아랍에미리트"
        case 5: return "파키스탄/인도"
        case 7: return "베트남, 태국"
        case 8: return "중국, 홍콩, 싱가포르"
        case 9: return "한국, 일본"
        case 10: return "호주 동부"
        case 12: return "뉴질랜드"
        default: return ""
        }
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "사진 폴더 선택"
        panel.message = "지오태깅할 사진이 있는 폴더를 선택하세요"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK {
            targetFolder = panel.url
            countPhotos()
            addLog("폴더 선택: \(panel.url?.lastPathComponent ?? "")")
        }
    }
    
    private func countPhotos() {
        guard let folder = targetFolder else { return }
        
        let allExtensions = rawExtensions.union(imageExtensions)
        
        var count = 0
        var rawCount = 0
        var imageCount = 0
        
        if let enumerator = FileManager.default.enumerator(at: folder,
                                                           includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if allExtensions.contains(ext) {
                    count += 1
                    if rawExtensions.contains(ext) {
                        rawCount += 1
                    } else if imageExtensions.contains(ext) {
                        imageCount += 1
                    }
                }
            }
        }
        
        photoCount = count
        
        // 파일 형식별 개수 로그
        if count > 0 {
            var details = "📊 파일 분석: 총 \(count)개"
            if rawCount > 0 {
                details += " (RAW: \(rawCount)개"
            }
            if imageCount > 0 {
                if rawCount > 0 {
                    details += ", 이미지: \(imageCount)개)"
                } else {
                    details += " (이미지: \(imageCount)개)"
                }
            } else if rawCount > 0 {
                details += ")"
            }
            addLog(details)
        }
    }
    
    private func findExiftoolPath() -> String {
        // 먼저 PATH에서 찾기
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["exiftool"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                addLog("exiftool 경로: \(path)")
                return path
            }
        } catch {
            addLog("which 명령 실행 실패: \(error.localizedDescription)")
        }
        
        // homebrew 설치 경로 직접 확인
        let possiblePaths = [
            "/opt/homebrew/bin/exiftool",     // Apple Silicon
            "/usr/local/bin/exiftool",        // Intel Mac
            "/usr/bin/exiftool"               // System
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                addLog("exiftool 경로 (직접 확인): \(path)")
                return path
            }
        }
        
        addLog("❌ exiftool을 찾을 수 없습니다")
        return ""
    }
    
    // RAW 파일 확장자 정의 (Lightroom 호환을 위해 XMP 사이드카 필요)
    private let rawExtensions = Set([
        "3fr", "fff",  // Hasselblad
        "dng",         // Adobe DNG
        "arw", "sr2", "srf",  // Sony
        "cr2", "cr3", "crw",  // Canon
        "nef", "nrw",  // Nikon
        "raf",         // Fujifilm
        "orf",         // Olympus
        "rw2",         // Panasonic
        "pef", "ptx",  // Pentax
        "srw",         // Samsung
        "x3f",         // Sigma
        "iiq",         // Phase One
        "rwl", "raw",  // Leica
        "gpr",         // GoPro
        "ari",         // ARRI
        "bay", "cap", "erf", "k25", "kdc", "mef", "mos", "mrw", "pxn"  // 기타
    ])
    
    // 일반 이미지 확장자 (직접 embed 가능)
    private let imageExtensions = Set([
        "jpg", "jpeg", "png", "gif", "bmp", "webp",
        "heic", "heif", "avif", "jxl",
        "tiff", "tif"  // TIFF는 embed 가능
    ])
    
    func startGeotagging() {
        guard let gpx = gpxFile,
              let folder = targetFolder else { return }
        
        isProcessing = true
        progress = 0
        statusMessage = "처리 중..."
        
        // exiftool 경로 찾기 (homebrew 설치 경로 포함)
        let exiftoolPath = findExiftoolPath()
        
        guard !exiftoolPath.isEmpty else {
            isProcessing = false
            statusMessage = "exiftool 없음"
            showError("exiftool이 설치되지 않았습니다. 터미널에서 'brew install exiftool'을 실행하세요.")
            return
        }
        
        // Auto 모드에서 파일 형식별로 처리
        if processingMode == .auto {
            processAutoMode(exiftoolPath: exiftoolPath, gpx: gpx, folder: folder)
        } else {
            // 단일 모드 처리
            processSingleMode(exiftoolPath: exiftoolPath, gpx: gpx, folder: folder)
        }
    }
    
    private func processAutoMode(exiftoolPath: String, gpx: URL, folder: URL) {
        addLog("🔄 Auto 모드: 파일 형식에 따라 자동 처리")
        
        // RAW 파일용 프로세스 (XMP 사이드카)
        let rawTask = createExiftoolProcess(
            exiftoolPath: exiftoolPath,
            gpx: gpx,
            folder: folder,
            extensions: Array(rawExtensions),
            useXMP: true
        )
        
        // 일반 이미지용 프로세스 (직접 embed)
        let imageTask = createExiftoolProcess(
            exiftoolPath: exiftoolPath,
            gpx: gpx,
            folder: folder,
            extensions: Array(imageExtensions),
            useXMP: false
        )
        
        var completedTasks = 0
        let totalTasks = 2
        
        // RAW 파일 처리
        addLog("📄 RAW 파일 처리 중 (XMP 사이드카 생성)...")
        runExiftoolTask(rawTask) { [weak self] success in
            completedTasks += 1
            if success {
                self?.addLog("✅ RAW 파일 처리 완료")
            }
            if completedTasks == totalTasks {
                self?.finishProcessing(success: true)
            }
        }
        
        // 일반 이미지 처리
        addLog("📝 일반 이미지 처리 중 (메타데이터 직접 삽입)...")
        runExiftoolTask(imageTask) { [weak self] success in
            completedTasks += 1
            if success {
                self?.addLog("✅ 일반 이미지 처리 완료")
            }
            if completedTasks == totalTasks {
                self?.finishProcessing(success: true)
            }
        }
    }
    
    private func processSingleMode(exiftoolPath: String, gpx: URL, folder: URL) {
        let allExtensions = Array(rawExtensions.union(imageExtensions))
        let useXMP = (processingMode == .sidecar)
        
        let task = createExiftoolProcess(
            exiftoolPath: exiftoolPath,
            gpx: gpx,
            folder: folder,
            extensions: allExtensions,
            useXMP: useXMP
        )
        
        let modeDesc = useXMP ? "XMP 사이드카 모드" : "직접 embed 모드"
        addLog("📍 \(modeDesc)로 처리 중...")
        
        runExiftoolTask(task) { [weak self] success in
            self?.finishProcessing(success: success)
        }
    }
    
    private func createExiftoolProcess(
        exiftoolPath: String,
        gpx: URL,
        folder: URL,
        extensions: [String],
        useXMP: Bool
    ) -> Process {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: exiftoolPath)
        
        // exiftool 인자 구성
        var arguments = [
            "-r",  // 재귀적으로 하위 폴더 처리
            "-geotag=\(gpx.path)",
            "-api", "GeoMaxIntSecs=\(maxInterpolation)",
            "-api", "GeoMaxExtSecs=\(maxExtrapolation)"
        ]
        
        // 타임존 오프셋 설정
        if !timezoneOffset.isEmpty && timezoneOffset != "+00:00" {
            arguments.append("-geotime<${DateTimeOriginal}\(timezoneOffset)")
        }
        
        // XMP 사이드카 또는 직접 embed
        if useXMP {
            arguments.append("-o")
            arguments.append("%d%f.xmp")
        } else {
            arguments.append("-overwrite_original_in_place")
        }
        
        // 파일 확장자 필터
        for ext in extensions {
            arguments.append("-ext")
            arguments.append(ext)
        }
        
        // 대상 폴더 추가
        arguments.append(folder.path)
        
        task.arguments = arguments
        return task
    }
    
    private func runExiftoolTask(_ task: Process, completion: @escaping (Bool) -> Void) {
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        let outputHandle = pipe.fileHandleForReading
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    self.processOutput(output)
                }
            }
        }
        
        task.terminationHandler = { process in
            DispatchQueue.main.async {
                // Remove from active tasks
                if let index = self.activeTasks.firstIndex(of: process) {
                    self.activeTasks.remove(at: index)
                }
                
                let success = process.terminationStatus == 0
                if !success {
                    self.addLog("⚠️ 처리 중 오류 발생 (코드: \(process.terminationStatus))")
                }
                outputHandle.readabilityHandler = nil
                completion(success)
            }
        }
        
        do {
            activeTasks.append(task)  // Add to active tasks
            try task.run()
        } catch {
            addLog("❌ 프로세스 실행 실패: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    private func finishProcessing(success: Bool) {
        isProcessing = false
        if success {
            progress = 1.0
            statusMessage = "완료"
            addLog("✅ 모든 파일 처리가 완료되었습니다!")
            addLog("💡 Lightroom에서 RAW 파일과 XMP를 함께 가져오면 위치 정보가 자동으로 적용됩니다.")
        } else {
            statusMessage = "오류 발생"
            showError("일부 파일 처리 중 오류가 발생했습니다. 로그를 확인하세요.")
        }
    }
    
    private func processOutput(_ output: String) {
        let lines = output.split(separator: "\n")
        for line in lines {
            let lineStr = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if !lineStr.isEmpty {
                addLog(lineStr)
                
                // Update progress / 진행률 업데이트
                if lineStr.contains("Processing") || lineStr.contains("처리") {
                    progress = min(progress + 0.1, 0.9)
                } else if lineStr.contains("directories scanned") {
                    progress = 0.3
                } else if lineStr.contains("image files") {
                    progress = 0.7
                } else if lineStr.contains("✅") || lineStr.lowercased().contains("done") {
                    progress = 1.0
                }
            }
        }
    }
    
    func stopProcessing() {
        // Terminate all active tasks
        for task in activeTasks {
            task.terminate()
        }
        activeTasks.removeAll()
        isProcessing = false
        statusMessage = "취소됨"
        addLog("사용자가 처리를 취소했습니다")
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(),
                                                      dateStyle: .none,
                                                      timeStyle: .medium)
        logMessages.append("[\(timestamp)] \(message)")
        
        // Keep max 500 lines / 최대 500줄 유지
        if logMessages.count > 500 {
            logMessages.removeFirst(logMessages.count - 500)
        }
    }
    
    private func showError(_ message: String) {
        alertMessage = message
        showingAlert = true
        addLog("❌ \(message)")
    }
}

// MARK: - Main Content View / 메인 콘텐츠 뷰
struct ContentView: View {
    @StateObject private var viewModel = GeoTagViewModel()
    @State private var showingLogs = false
    @State private var hoveredMode: GeoTagViewModel.ProcessingMode?
    
    var body: some View {
        ZStack {
            // Background gradient / 배경 그라데이션
            LinearGradient(
                colors: [Color(nsColor: .controlBackgroundColor),
                        Color(nsColor: .windowBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header / 헤더
                HeaderView()
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    .padding(.bottom, 25)
                
                // Main content / 메인 콘텐츠
                ScrollView {
                    VStack(spacing: 25) {
                        // GPX file selection / GPX 파일 선택
                        FileSelectionCard(
                            title: "GPX 트랙 파일",
                            icon: "location.circle.fill",
                            file: viewModel.gpxFile,
                            placeholder: "GPS 트랙 파일을 선택하세요",
                            action: viewModel.selectGPXFile
                        )
                        
                        // Photo folder selection / 사진 폴더 선택
                        FolderSelectionCard(
                            title: "사진 폴더",
                            icon: "photo.on.rectangle.angled",
                            folder: viewModel.targetFolder,
                            photoCount: viewModel.photoCount,
                            placeholder: "사진이 있는 폴더를 선택하세요",
                            action: viewModel.selectFolder
                        )
                        
                        // Processing mode selection / 처리 모드 선택
                        VStack(alignment: .leading, spacing: 12) {
                            Label("처리 모드", systemImage: "gearshape.2.fill")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(GeoTagViewModel.ProcessingMode.allCases, id: \.self) { mode in
                                    ModeButton(
                                        mode: mode,
                                        isSelected: viewModel.processingMode == mode,
                                        isHovered: hoveredMode == mode
                                    ) {
                                        viewModel.processingMode = mode
                                    }
                                    .onHover { hovering in
                                        hoveredMode = hovering ? mode : nil
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Advanced settings / 고급 설정
                        AdvancedSettingsView(viewModel: viewModel)
                            .padding(.horizontal, 30)
                        
                        // Execute button / 실행 버튼
                        ProcessButton(viewModel: viewModel)
                            .padding(.horizontal, 30)
                            .padding(.top, 10)
                        
                        // Progress / 진행률
                        if viewModel.isProcessing || viewModel.progress > 0 {
                            ProgressBarView(viewModel: viewModel)
                                .padding(.horizontal, 30)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.vertical, 20)
                }
                
                // Bottom status bar / 하단 상태 바
                StatusBar(viewModel: viewModel, showingLogs: $showingLogs)
            }
        }
        .sheet(isPresented: $showingLogs) {
            LogsView(viewModel: viewModel)
        }
        .alert("오류", isPresented: $viewModel.showingAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

// MARK: - Components / 컴포넌트
struct HeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text("PhotoPin")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("사진에 GPS 위치 정보를 추가합니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct FileSelectionCard: View {
    let title: String
    let icon: String
    let file: URL?
    let placeholder: String
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let file = file {
                        Text(file.lastPathComponent)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.medium)
                        Text(file.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(placeholder)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: action) {
                    Label("선택", systemImage: "folder")
                        .frame(width: 90)
                }
                .controlSize(.large)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        }
        .padding(.horizontal, 30)
    }
}

struct FolderSelectionCard: View {
    let title: String
    let icon: String
    let folder: URL?
    let photoCount: Int
    let placeholder: String
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let folder = folder {
                        HStack {
                            Text(folder.lastPathComponent)
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.medium)
                            if photoCount > 0 {
                                Text("(\(photoCount)개)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        Text(folder.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(placeholder)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: action) {
                    Label("선택", systemImage: "folder")
                        .frame(width: 90)
                }
                .controlSize(.large)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        }
        .padding(.horizontal, 30)
    }
}

struct ModeButton: View {
    let mode: GeoTagViewModel.ProcessingMode
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.title2)
                Text(mode.description)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) :
                          isHovered ? Color.gray.opacity(0.1) :
                          Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: GeoTagViewModel
    @State private var isExpanded = false
    @State private var showingTimezoneHelp = false
    @State private var showingInterpolationHelp = false
    @State private var showingExtrapolationHelp = false
    
    private let labelWidth: CGFloat = 140
    private let fieldWidth: CGFloat = 100
    private let defaultLabelWidth: CGFloat = 180
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                // Timezone setting / 타임존 설정
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        Label("타임존 오프셋", systemImage: "clock")
                            .frame(width: labelWidth, alignment: .leading)
                        
                        TextField("예: +09:00", text: $viewModel.timezoneOffset)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: fieldWidth)
                        
                        Button(action: { showingTimezoneHelp.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingTimezoneHelp) {
                            TimezoneHelpView()
                                .frame(width: 400, height: 280)
                        }
                        
                        Text("자동 감지됨")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .opacity(viewModel.timezoneOffset != "+09:00" ? 1 : 0)
                        
                        Spacer()
                    }
                    .frame(height: 36)
                    
                    HStack {
                        Text("일반적인 시간대: 한국/일본 +09:00, 중국 +08:00")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, labelWidth + 12)
                    }
                    .frame(height: 20)
                }
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Interpolation time / 보간 시간
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        Label("보간 시간", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                            .frame(width: labelWidth, alignment: .leading)
                        
                        TextField("", value: $viewModel.maxInterpolation, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: fieldWidth)
                        
                        Button(action: { showingInterpolationHelp.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingInterpolationHelp) {
                            InterpolationHelpView()
                                .frame(width: 400, height: 350)
                        }
                        
                        Text("초")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .frame(height: 36)
                    
                    HStack {
                        Text("기본값: 1800초 (30분) - GPS 포인트 사이 위치 추정")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, labelWidth + 12)
                    }
                    .frame(height: 20)
                }
                .padding(.vertical, 8)
                
                // Extrapolation time / 외삽 시간
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        Label("외삽 시간", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                            .frame(width: labelWidth, alignment: .leading)
                        
                        TextField("", value: $viewModel.maxExtrapolation, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: fieldWidth)
                        
                        Button(action: { showingExtrapolationHelp.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingExtrapolationHelp) {
                            ExtrapolationHelpView()
                                .frame(width: 400, height: 350)
                        }
                        
                        Text("초")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .frame(height: 36)
                    
                    HStack {
                        Text("기본값: 18000초 (5시간) - GPS 트랙 밖 위치 추정")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, labelWidth + 12)
                    }
                    .frame(height: 20)
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        } label: {
            HStack {
                Label("고급 설정", systemImage: "gearshape")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(isExpanded ? "접기" : "펼치기")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}

// MARK: - Timezone Help View / 타임존 도움말 뷰
struct TimezoneHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("타임존 오프셋이란?")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("카메라 시간과 GPS 시간의 차이를 보정합니다.")
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("자동 감지", systemImage: "wand.and.stars")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    Text("GPX 파일에 시간대 정보가 있으면 자동으로 감지합니다.")
                        .font(.caption)
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("주요 시간대:")
                        .font(.subheadline.bold())
                    Text("• 한국/일본: +09:00")
                    Text("• 중국/홍콩: +08:00")
                    Text("• 베트남/태국: +07:00")
                    Text("• 인도: +05:30")
                    Text("• 유럽: +01:00 ~ +02:00")
                    Text("• 미국 동부: -05:00")
                    Text("• 미국 서부: -08:00")
                }
                .font(.caption)
                
                Text("💡 카메라가 현지 시간이고 GPX가 UTC면 설정 필요")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Help Views / 도움말 뷰
struct InterpolationHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("보간 시간이란?")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("GPS 트랙의 두 지점 사이에서 위치를 추정하는 최대 시간입니다.")
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("예시", systemImage: "lightbulb")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Text("• GPS: 10:00 (서울역) → 10:30 (강남역)")
                        .font(.system(.caption, design: .monospaced))
                    Text("• 사진: 10:15에 촬영")
                        .font(.system(.caption, design: .monospaced))
                    Text("→ 중간 지점(예: 한강대교)으로 위치 추정")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("권장 설정:")
                        .font(.subheadline.bold())
                    Text("• 도보/하이킹: 1800초 (30분)")
                    Text("• 자전거: 600초 (10분)")
                    Text("• 자동차: 300초 (5분)")
                    Text("• 비행기: 3600초 (1시간)")
                }
                .font(.caption)
                
                Text("💡 팁: 이동 속도가 빠를수록 작은 값을 사용하세요.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct ExtrapolationHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("외삽 시간이란?")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("GPS 트랙의 시작/끝 지점 밖에서 위치를 추정하는 최대 시간입니다.")
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("예시", systemImage: "lightbulb")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Text("• GPS 트랙: 10:00 시작 ~ 15:00 종료")
                        .font(.system(.caption, design: .monospaced))
                    Text("• 사진: 09:30 또는 15:30에 촬영")
                        .font(.system(.caption, design: .monospaced))
                    Text("→ 가장 가까운 GPS 지점 위치 사용")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("사용 시나리오:")
                        .font(.subheadline.bold())
                    Text("• GPS 켜기 전/후 촬영한 사진")
                    Text("• 실내에서 GPS 신호 끊긴 경우")
                    Text("• 배터리 절약으로 GPS 껐다 켠 경우")
                }
                .font(.caption)
                
                Text("⚠️ 주의: 너무 큰 값은 부정확한 위치를 생성할 수 있습니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("권장: 5-30분 이내")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }
}

struct ProcessButton: View {
    @ObservedObject var viewModel: GeoTagViewModel
    
    var body: some View {
        Button(action: {
            if viewModel.isProcessing {
                viewModel.stopProcessing()
            } else {
                viewModel.startGeotagging()
            }
        }) {
            HStack {
                Image(systemName: viewModel.isProcessing ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                Text(viewModel.isProcessing ? "처리 중지" : "지오태깅 시작")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canStartProcessing && !viewModel.isProcessing)
    }
}

struct ProgressBarView: View {
    @ObservedObject var viewModel: GeoTagViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.progress, total: 1.0)
                .progressViewStyle(.linear)
            
            HStack {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}

struct StatusBar: View {
    @ObservedObject var viewModel: GeoTagViewModel
    @Binding var showingLogs: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.isProcessing ? Color.orange :
                          viewModel.progress == 1.0 ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(viewModel.statusMessage)
                    .font(.caption)
            }
            
            Spacer()
            
            Button(action: { showingLogs = true }) {
                Label("로그 보기", systemImage: "doc.text")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct LogsView: View {
    @ObservedObject var viewModel: GeoTagViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / 헤더
            HStack {
                Text("처리 로그")
                    .font(.headline)
                Spacer()
                Button("닫기") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            // Log content / 로그 내용
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(viewModel.logMessages.enumerated()), id: \.offset) { index, log in
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: viewModel.logMessages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(viewModel.logMessages.count - 1, anchor: .bottom)
                    }
                }
            }
            
            // Bottom buttons / 하단 버튼
            HStack {
                Button("로그 복사") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.logMessages.joined(separator: "\n"),
                                                  forType: .string)
                }
                .buttonStyle(.bordered)
                
                Button("로그 지우기") {
                    viewModel.logMessages.removeAll()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 600, height: 400)
    }
}