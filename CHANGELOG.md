# 변경 이력 (Changelog)

## [1.0.0] - 2024-09-06

### 🎉 첫 번째 릴리즈

#### ✨ 주요 기능
- **스마트 Auto 모드**: 파일 형식별 최적 처리 방식 자동 선택
- **GPX 시간대 자동 감지**: GPX 파일의 TZ 정보 자동 파싱
- **정밀 위치 추정**: 보간/외삽 알고리즘으로 정확한 위치 계산
- **네이티브 macOS 앱**: Swift/SwiftUI 기반 모던 UI

#### 📸 지원 포맷
- 일반 이미지: JPEG, PNG, HEIC, HEIF, TIFF, WebP
- Canon: CR2, CR3, CRW
- Nikon: NEF, NRW  
- Sony: ARW, SR2, SRF
- Fujifilm: RAF
- Hasselblad: 3FR, FFF
- 기타 40+ RAW 포맷

#### 🛠️ 기술 스택
- **백엔드**: Python 3.x + ExifTool
- **프론트엔드**: Swift 5.9 + SwiftUI
- **빌드**: PyInstaller (구 버전), Swift Package Manager

#### 📝 문서
- 상세한 README.md
- MIT 라이선스
- 프로젝트 구조 정리

### 개발 히스토리

#### Phase 1: Python CLI
- 기본 지오태깅 기능 구현
- ExifTool 래퍼 개발
- Sidecar/Embed 모드 지원

#### Phase 2: Dear PyGui 시도
- Python 기반 GUI 개발
- 한글 폰트 문제 발생
- UI/UX 한계로 중단

#### Phase 3: Swift 네이티브 앱
- SwiftUI로 완전 재개발
- macOS 네이티브 디자인
- 완벽한 한글 지원
- 다크모드 대응

---

## 향후 계획 (Roadmap)

### v1.1.0
- [ ] 드래그 & 드롭 기능
- [ ] 배치 처리 큐
- [ ] 실행 취소 기능

### v1.2.0
- [ ] iCloud 동기화
- [ ] Photos.app 확장
- [ ] 다국어 지원

### v2.0.0
- [ ] iOS 버전
- [ ] 클라우드 GPX 저장소
- [ ] AI 기반 위치 추천