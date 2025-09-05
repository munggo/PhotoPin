#!/usr/bin/env python3
import argparse, os, shutil, subprocess, sys

# All photo and RAW formats / 모든 사진 및 RAW 포맷
DEFAULT_EXTS = [
    # Common image formats / 일반 이미지
    "jpg","jpeg","png","gif","bmp","webp",
    "heic","heif","avif","jxl",
    # Common RAW formats / 일반 RAW
    "tif","tiff","dng",
    # Camera-specific RAW formats / 카메라별 RAW
    "arw","sr2","srf",  # Sony / 소니
    "cr2","cr3","crw",  # Canon / 캐논
    "nef","nrw",  # Nikon / 니콘
    "raf",  # Fujifilm / 후지필름
    "orf",  # Olympus / 올림푸스
    "rw2",  # Panasonic / 파나소닉
    "pef","ptx",  # Pentax / 펜탁스
    "srw",  # Samsung / 삼성
    "x3f",  # Sigma / 시그마
    "3fr","fff",  # Hasselblad / 핫셀블라드
    "iiq",  # Phase One / 페이즈원
    "rwl","raw",  # Leica / 라이카
    "r3d",  # RED / 레드
    "ari",  # ARRI / 아리
    "bay","cap","erf","k25","kdc","mef","mos","mrw","pxn","R3D"
]

# Formats requiring XMP sidecar in Auto mode / Auto 모드에서 XMP 사이드카가 필요한 포맷
SIDECAR_ONLY_EXTS = [
    "3fr", "fff",  # Hasselblad
    "iiq",  # Phase One / 페이즈원
    "x3f",  # Sigma / 시그마
    "r3d", "ari",  # Cinema cameras / 시네마 카메라
]

def build_cmd(args, file_ext=None):
    # Common options / 공통 옵션
    cmd = ["exiftool",
           "-r",  # Recursive subdirectories / 하위폴더까지 재귀
           f"-geotag={args.gpx}",
           "-api", f"GeoMaxIntSecs={args.max_int}",   # Max interpolation time between GPS points (seconds) / GPX 포인트 간 보간 허용 시간(초)
           "-api", f"GeoMaxExtSecs={args.max_ext}"    # Max extrapolation time outside track (seconds) / 궤적 밖에서 허용할 최대 외삽 시간(초)
    ]
    # Offset correction when camera uses local time and GPX uses UTC / 카메라 시간이 로컬타임이고 GPX가 UTC인 경우, 오프셋 보정
    # Example: For photos taken in Korea (+09:00) with local time / 예: 한국(+09:00)에서 현지시로 찍었으면 '-geotime<${DateTimeOriginal}+09:00'
    if args.tz_offset:
        cmd.append(f"-geotime<${{DateTimeOriginal}}{args.tz_offset}")

    # Process by file extension in Auto mode / Auto 모드인 경우 파일 확장자별로 처리
    if args.mode == "auto" and file_ext:
        # Process specific extension only / 특정 확장자만 처리
        cmd += ["-ext", file_ext]
        # Check if format requires sidecar / sidecar가 필요한 포맷인지 확인
        if file_ext.lower() in [e.lower() for e in SIDECAR_ONLY_EXTS]:
            cmd += ["-o", "%d%f.xmp"]
        else:
            cmd += ["-overwrite_original_in_place"]
    else:
        # Process existing modes / 기존 모드 처리
        # Extension filter / 확장자 필터
        for ext in (args.exts or DEFAULT_EXTS):
            cmd += ["-ext", ext]

        # Branch by mode / 모드별 분기
        if args.mode == "sidecar":
            # Preserve original, write to same-named .xmp / 원본은 보존, 같은 이름의 .xmp에 기록
            cmd += ["-o", "%d%f.xmp"]
        else:
            # Write directly to original (for supported formats) / 원본에 직접 기록 (가능 포맷에 한해)
            cmd += ["-overwrite_original_in_place"]

    cmd.append(args.target_dir)
    return cmd

def main():
    p = argparse.ArgumentParser(description="Geotag photos from a GPX track using ExifTool (sidecar or embed).")
    p.add_argument("--gpx", required=True, help="GPX track file path")
    p.add_argument("--target-dir", required=True, help="Root directory containing photos")
    p.add_argument("--mode", choices=["sidecar","embed","auto"], default="auto",
                   help="Write mode: sidecar (XMP), embed (direct), or auto (smart detection)")
    p.add_argument("--tz-offset", default=None,
                   help="Timezone offset for -geotime (e.g. +09:00, -07:00). Omit if your DateTimeOriginal is already UTC aligned.")
    p.add_argument("--max-int", type=int, default=1800,
                   help="Max interpolation seconds between GPX fixes (default 1800=30min)")
    p.add_argument("--max-ext", type=int, default=120,
                   help="Max extrapolation seconds outside GPX track (default 120=2min)")
    p.add_argument("--exts", nargs="*", help="File extensions to process (defaults include RAW & common formats)")
    args = p.parse_args()

    if not shutil.which("exiftool"):
        print("ERROR: exiftool not found. Install it first (e.g., brew install exiftool).", file=sys.stderr)
        sys.exit(1)
    if not os.path.isfile(args.gpx):
        print(f"ERROR: GPX not found: {args.gpx}", file=sys.stderr)
        sys.exit(1)
    if not os.path.isdir(args.target_dir):
        print(f"ERROR: target dir not found: {args.target_dir}", file=sys.stderr)
        sys.exit(1)

    # Auto mode processing / Auto 모드 처리
    if args.mode == "auto":
        print("🔄 Auto mode: Processing files by type... / 파일 타입별로 처리 중...")
        # Group by file type / 파일 타입별로 그룹화
        extensions_in_dir = set()
        for ext in DEFAULT_EXTS:
            for _ in os.listdir(args.target_dir):
                if _.lower().endswith(f".{ext.lower()}"):
                    extensions_in_dir.add(ext.lower())
                    break
        
        # Process sidecar-required formats first / sidecar가 필요한 포맷 먼저 처리
        for ext in extensions_in_dir:
            if ext in [e.lower() for e in SIDECAR_ONLY_EXTS]:
                print(f"  📄 Processing {ext.upper()} files with XMP sidecar... / {ext.upper()} 파일을 XMP 사이드카로 처리 중...")
                cmd = build_cmd(args, file_ext=ext)
                subprocess.run(cmd, check=False)
        
        # Process remaining formats with embed / 나머지 포맷은 embed로 처리
        for ext in extensions_in_dir:
            if ext not in [e.lower() for e in SIDECAR_ONLY_EXTS]:
                print(f"  📝 Processing {ext.upper()} files with direct embed... / {ext.upper()} 파일을 직접 임베드로 처리 중...")
                cmd = build_cmd(args, file_ext=ext)
                subprocess.run(cmd, check=False)
        
        print("✅ Auto mode geotagging done. / Auto 모드 지오태깅 완료.")
    else:
        # Process existing modes / 기존 모드 처리
        cmd = build_cmd(args)
        print("Running:", " ".join(cmd))
        try:
            subprocess.run(cmd, check=True)
            print("✅ Geotagging done. / 지오태깅 완료.")
        except subprocess.CalledProcessError as e:
            print("❌ exiftool failed. / exiftool 실패.", file=sys.stderr)
            sys.exit(e.returncode)
    
    print("TIP: Verify a file with / 파일 확인 명령: exiftool -a -G1 -s <file>")

if __name__ == "__main__":
    main()
