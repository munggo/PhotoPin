# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요
GPX 트랙 파일을 사용하여 사진에 지오태그(위치 정보)를 추가하는 Python 스크립트입니다. ExifTool을 백엔드로 사용하며, XMP 사이드카 파일이나 직접 임베드 방식을 지원합니다.

## 필수 의존성
- Python 3.x
- ExifTool (`brew install exiftool` 또는 시스템 패키지 매니저로 설치)

## 주요 명령어

### 실행
```bash
# XMP 사이드카 모드 (기본, 안전)
python3 geotag.py --gpx track.gpx --target-dir /path/to/photos

# 파일에 직접 임베드 모드
python3 geotag.py --gpx track.gpx --target-dir /path/to/photos --mode embed

# 타임존 오프셋 지정 (카메라가 현지 시간인 경우)
python3 geotag.py --gpx track.gpx --target-dir /path/to/photos --tz-offset +09:00
```

### 검증
```bash
# 지오태그가 적용된 파일 확인
exiftool -a -G1 -s <photo_file>
```

## 아키텍처 및 구조

### 핵심 컴포넌트
- **build_cmd()**: ExifTool 명령어를 동적으로 구성
- **main()**: 인자 파싱, 유효성 검사, 실행

### 동작 방식
1. GPX 파일의 GPS 트랙 데이터와 사진의 DateTimeOriginal 시간을 매칭
2. 시간상 가장 가까운 GPS 포인트를 찾아 위치 정보 적용
3. `max_int`(기본 30분) 범위 내에서 GPS 포인트 간 보간
4. `max_ext`(기본 2분) 범위 내에서 트랙 외부 외삽 허용

### 지원 파일 형식
- 일반 이미지: JPG, JPEG, PNG, HEIC, HEIF
- RAW 포맷: DNG, ARW, CR2, CR3, NEF, RAF, ORF, RW2, TIF, TIFF
- Hasselblad: 3FR, FFF

### 모드별 특징
- **sidecar**: 원본 파일 보존, .xmp 파일에 메타데이터 저장 (모든 포맷 지원)
- **embed**: 파일에 직접 기록 (일부 RAW 포맷은 제한적)

## 개발 시 주의사항
- ExifTool 설치 여부 확인 필수
- 파일 경로와 GPX 파일 존재 여부 검증
- 타임존 처리: GPX는 일반적으로 UTC, 카메라는 현지 시간일 수 있음
- 대량 파일 처리 시 `-r` 옵션으로 재귀적 처리