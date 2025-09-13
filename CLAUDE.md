# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요
PhotoPin - GPX 트랙 파일을 사용하여 사진에 지오태그(위치 정보)를 추가하는 macOS 네이티브 앱입니다. SwiftUI로 개발되었으며, ExifTool을 백엔드로 사용합니다.

**중요**: 원본 파일 보호를 위해 항상 XMP 사이드카 파일만 생성합니다.

## 필수 의존성
- macOS 11.0+
- Swift 5.5+
- ExifTool (`brew install exiftool`)

## 빌드 및 실행

### 개발 모드
```bash
cd PhotoPin
swift build
swift run
```

### 앱 빌드
```bash
cd PhotoPin
swift build -c release
# 또는 Xcode에서 열기
open Package.swift
```

## 주요 특징

### XMP 전용 모드
- **안전성**: 원본 파일을 절대 수정하지 않음
- **호환성**: Lightroom, Photoshop, Capture One 등 주요 소프트웨어 지원
- **중복 처리**: 동일한 파일명의 다른 확장자(예: IMG_001.jpg, IMG_001.raw)는 하나의 XMP 파일로 관리
- **스마트 스킵**: 이미 XMP 파일이 존재하는 경우 자동으로 건너뛰어 재처리 방지

### 지원 파일 형식
- 일반 이미지: JPG, JPEG, PNG, HEIC, HEIF, TIFF
- RAW 포맷: DNG, ARW, CR2, CR3, NEF, RAF, ORF, RW2
- Hasselblad: 3FR, FFF
- Phase One: IIQ
- 기타: 대부분의 카메라 RAW 포맷

### 동작 방식
1. GPX 파일의 GPS 트랙 데이터와 사진의 DateTimeOriginal 시간을 매칭
2. 시간상 가장 가까운 GPS 포인트를 찾아 위치 정보 적용
3. 보간/외삽을 통해 정확한 위치 추정
4. XMP 사이드카 파일에 위치 정보 저장

## 아키텍처

### 주요 컴포넌트
- **PhotoPinApp.swift**: 메인 앱 엔트리 포인트와 UI
- **GeoTagViewModel**: 비즈니스 로직 및 ExifTool 프로세스 관리
  - XMP 파일 존재 여부 체크
  - 처리가 필요한 파일과 스킵할 파일 구분
  - 실시간 상태 업데이트
- **ContentView**: 메인 UI 레이아웃

### ExifTool 통합
- Process API를 통한 ExifTool 실행
- 실시간 로그 스트리밍
- 에러 핸들링 및 프로세스 관리

## 개발 가이드

### UI/UX 원칙
- macOS 네이티브 디자인 가이드라인 준수
- 직관적이고 간단한 인터페이스
- 실시간 피드백 제공

### 코드 스타일
- SwiftUI 베스트 프랙티스 적용
- MVVM 패턴 사용
- 한글/영어 이중 주석

### 테스트
```bash
# ExifTool 설치 확인
which exiftool

# XMP 파일 검증
exiftool -a -G1 -s <photo_file.xmp>
```

## 주의사항
- ExifTool 설치 필수
- GPX 파일 시간대와 카메라 시간대 확인
- 대량 파일 처리 시 메모리 사용량 모니터링