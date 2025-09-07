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
