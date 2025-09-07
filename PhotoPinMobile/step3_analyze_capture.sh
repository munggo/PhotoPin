#!/bin/bash

echo "================================================"
echo "🔍 STEP 3: 캡처된 BLE 로그 분석"
echo "================================================"
echo ""

LOG_DIR="/Users/munkyo/works/ai-code/photo/PhotoPinMobile/logs"
LOG_FILE="$LOG_DIR/phocus_ble_capture.log"

echo "📂 로그 파일 확인 중..."
if [ -f "$LOG_FILE" ]; then
    echo "✅ 로그 파일 발견: $LOG_FILE"
    echo "   크기: $(du -h "$LOG_FILE" | cut -f1)"
    echo "   라인 수: $(wc -l < "$LOG_FILE")"
else
    echo "❌ 로그 파일이 없습니다: $LOG_FILE"
    echo "   먼저 step2_capture_phocus.sh를 실행하여 캡처를 완료하세요."
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔎 BLE 통신 패턴 검색"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 분석 결과 파일
ANALYSIS_FILE="$LOG_DIR/ble_analysis.txt"

echo "" > "$ANALYSIS_FILE"
echo "=== Phocus BLE 통신 분석 결과 ===" >> "$ANALYSIS_FILE"
echo "분석 시간: $(date)" >> "$ANALYSIS_FILE"
echo "" >> "$ANALYSIS_FILE"

# 1. Service UUID 찾기
echo ""
echo "1️⃣ BLE Service UUIDs 검색..."
echo "━━━ Service UUIDs ━━━" >> "$ANALYSIS_FILE"
grep -i "service.*uuid\|uuid.*fff" "$LOG_FILE" | head -20 >> "$ANALYSIS_FILE" 2>/dev/null
grep -i "service.*uuid\|uuid.*fff" "$LOG_FILE" | head -5

# 2. Characteristic 찾기
echo ""
echo "2️⃣ BLE Characteristics 검색..."
echo "" >> "$ANALYSIS_FILE"
echo "━━━ Characteristics ━━━" >> "$ANALYSIS_FILE"
grep -i "characteristic\|fff[0-9]" "$LOG_FILE" | head -20 >> "$ANALYSIS_FILE" 2>/dev/null
grep -i "characteristic\|fff[0-9]" "$LOG_FILE" | head -5

# 3. Write 명령 찾기
echo ""
echo "3️⃣ Write 명령 패턴 검색..."
echo "" >> "$ANALYSIS_FILE"
echo "━━━ Write Commands ━━━" >> "$ANALYSIS_FILE"
grep -i "write.*0x\|wrote.*bytes\|writing.*value" "$LOG_FILE" | head -30 >> "$ANALYSIS_FILE" 2>/dev/null
grep -i "write.*0x\|wrote.*bytes\|writing.*value" "$LOG_FILE" | head -10

# 4. WiFi 관련 명령 찾기
echo ""
echo "4️⃣ WiFi 관련 키워드 검색..."
echo "" >> "$ANALYSIS_FILE"
echo "━━━ WiFi Related ━━━" >> "$ANALYSIS_FILE"
grep -i "wifi\|ssid\|network\|hotspot\|192\.168" "$LOG_FILE" | head -20 >> "$ANALYSIS_FILE" 2>/dev/null
grep -i "wifi\|ssid\|network\|hotspot" "$LOG_FILE" | head -5

# 5. Hex 값 패턴 찾기
echo ""
echo "5️⃣ Hex 데이터 패턴 검색..."
echo "" >> "$ANALYSIS_FILE"
echo "━━━ Hex Patterns ━━━" >> "$ANALYSIS_FILE"
grep -oE "0x[0-9a-fA-F]{2}([ ,]0x[0-9a-fA-F]{2})*" "$LOG_FILE" | sort -u | head -30 >> "$ANALYSIS_FILE" 2>/dev/null
grep -oE "0x[0-9a-fA-F]{2}([ ,]0x[0-9a-fA-F]{2})*" "$LOG_FILE" | sort -u | head -10

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 수동 분석 가이드"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Python 분석 스크립트 생성
cat > "$LOG_DIR/analyze_ble_log.py" << 'EOF'
#!/usr/bin/env python3
"""
Phocus BLE 로그 상세 분석 도구
"""

import re
import sys
from collections import defaultdict
from datetime import datetime

def analyze_log(log_file):
    """BLE 로그 파일 분석"""
    
    # 패턴 정의
    patterns = {
        'service': re.compile(r'service.*?(FFF\w)', re.I),
        'characteristic': re.compile(r'characteristic.*?(FFF\w)', re.I),
        'write': re.compile(r'write.*?(\[.*?\])|write.*?(0x[0-9a-fA-F]{2}.*?)[\s,\]]', re.I),
        'hex_data': re.compile(r'((?:0x[0-9a-fA-F]{2}[\s,]*)+)'),
        'wifi': re.compile(r'(wifi|ssid|network|hotspot|192\.168\.\d+\.\d+)', re.I),
        'timestamp': re.compile(r'(\d{2}:\d{2}:\d{2}\.\d+)')
    }
    
    results = defaultdict(list)
    
    print("📖 로그 파일 분석 중...")
    
    with open(log_file, 'r', errors='ignore') as f:
        for line_num, line in enumerate(f, 1):
            # 타임스탬프 추출
            ts_match = patterns['timestamp'].search(line)
            timestamp = ts_match.group(1) if ts_match else ""
            
            # Write 명령 찾기
            if 'write' in line.lower():
                hex_match = patterns['hex_data'].search(line)
                if hex_match:
                    hex_data = hex_match.group(1).strip()
                    results['writes'].append({
                        'line': line_num,
                        'time': timestamp,
                        'data': hex_data,
                        'context': line.strip()[:100]
                    })
            
            # Characteristic 찾기
            char_match = patterns['characteristic'].search(line)
            if char_match:
                results['characteristics'].append({
                    'uuid': char_match.group(1),
                    'line': line_num,
                    'context': line.strip()[:100]
                })
    
    return results

def print_analysis(results):
    """분석 결과 출력"""
    
    print("\n" + "="*50)
    print("📊 BLE 통신 분석 결과")
    print("="*50)
    
    # Characteristics
    if results['characteristics']:
        print("\n🔷 발견된 Characteristics:")
        seen = set()
        for char in results['characteristics']:
            if char['uuid'] not in seen:
                print(f"  - {char['uuid']} (라인 {char['line']})")
                seen.add(char['uuid'])
    
    # Write 명령 시퀀스
    if results['writes']:
        print(f"\n📝 Write 명령 시퀀스 (총 {len(results['writes'])}개):")
        for i, write in enumerate(results['writes'][:20], 1):
            print(f"\n  [{i}] 라인 {write['line']} ({write['time']})")
            print(f"      데이터: {write['data'][:60]}...")
            
            # Hex를 바이트로 변환 시도
            try:
                hex_vals = re.findall(r'0x([0-9a-fA-F]{2})', write['data'])
                if hex_vals:
                    bytes_data = [int(h, 16) for h in hex_vals]
                    print(f"      바이트: {bytes_data[:10]}")
            except:
                pass
    
    print("\n💡 추천 다음 단계:")
    print("1. Write 명령의 시간 순서 확인")
    print("2. 각 명령의 Characteristic UUID 매칭")
    print("3. 명령 패턴을 우리 앱 코드에 적용")

if __name__ == "__main__":
    log_file = sys.argv[1] if len(sys.argv) > 1 else "phocus_ble_capture.log"
    
    try:
        results = analyze_log(log_file)
        print_analysis(results)
    except FileNotFoundError:
        print(f"❌ 파일을 찾을 수 없습니다: {log_file}")
    except Exception as e:
        print(f"❌ 분석 중 오류 발생: {e}")
EOF

chmod +x "$LOG_DIR/analyze_ble_log.py"

echo ""
echo "🐍 Python 분석 도구 생성됨:"
echo "   $LOG_DIR/analyze_ble_log.py"
echo ""
echo "실행 방법:"
echo "   python3 $LOG_DIR/analyze_ble_log.py $LOG_FILE"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 분석 결과 저장됨"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📄 분석 파일: $ANALYSIS_FILE"
echo ""
cat "$ANALYSIS_FILE" | head -30
echo ""
echo "..."
echo "(전체 결과는 $ANALYSIS_FILE 파일 참조)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 다음 작업"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 분석된 BLE 명령 시퀀스 검토"
echo "2. 우리 앱의 BluetoothCameraManager.swift 수정"
echo "3. 정확한 명령 순서와 타이밍 적용"
echo "4. 테스트 및 디버깅"
echo ""
echo "준비되면 ./step4_apply_to_app.sh 실행"