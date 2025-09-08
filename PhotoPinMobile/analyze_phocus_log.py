#!/usr/bin/env python3

import json
import sys
import re
from datetime import datetime

def analyze_phocus_log(log_file):
    """Phocus BLE 로그 분석"""
    
    print("\n" + "="*60)
    print("📊 Phocus BLE 프로토콜 분석 결과")
    print("="*60)
    
    writes = []
    reads = []
    notifies = []
    
    try:
        with open(log_file, 'r') as f:
            for line in f:
                try:
                    if not line.strip():
                        continue
                        
                    data = json.loads(line)
                    msg = data.get('eventMessage', '')
                    
                    # FFF 관련 쓰기 찾기
                    if 'write' in msg.lower() and 'fff' in msg.lower():
                        # 데이터 추출
                        hex_pattern = r'0x[0-9a-fA-F]+'
                        hex_values = re.findall(hex_pattern, msg)
                        if hex_values:
                            writes.append({
                                'time': data.get('timestamp', ''),
                                'message': msg,
                                'hex': hex_values
                            })
                    
                    # FFF 관련 읽기 찾기
                    if 'read' in msg.lower() and 'fff' in msg.lower():
                        reads.append({
                            'time': data.get('timestamp', ''),
                            'message': msg
                        })
                    
                    # Notify 찾기
                    if 'notify' in msg.lower() and 'fff' in msg.lower():
                        notifies.append({
                            'time': data.get('timestamp', ''),
                            'message': msg
                        })
                        
                except json.JSONDecodeError:
                    continue
                except Exception as e:
                    continue
    
    except FileNotFoundError:
        print(f"❌ 로그 파일을 찾을 수 없습니다: {log_file}")
        return
    
    # 결과 출력
    print(f"\n📝 분석된 이벤트:")
    print(f"  - Write 명령: {len(writes)}개")
    print(f"  - Read 명령: {len(reads)}개")
    print(f"  - Notify 이벤트: {len(notifies)}개")
    
    if writes:
        print("\n🔵 Write 명령 시퀀스:")
        print("-" * 40)
        for i, w in enumerate(writes[:20], 1):  # 처음 20개만
            hex_str = ' '.join(w['hex'])
            print(f"{i:2}. {hex_str}")
            if 'FFF3' in w['message']:
                print(f"    → FFF3에 전송")
            elif 'FFF4' in w['message']:
                print(f"    → FFF4에 전송")
            elif 'FFF7' in w['message']:
                print(f"    → FFF7에 전송")
    
    if notifies:
        print("\n🔔 Notify 이벤트:")
        print("-" * 40)
        for i, n in enumerate(notifies[:10], 1):
            print(f"{i}. {n['message'][:100]}...")
    
    # 패턴 분석
    print("\n🔍 발견된 패턴:")
    print("-" * 40)
    
    # 공통 명령 찾기
    common_commands = {}
    for w in writes:
        hex_str = ' '.join(w['hex'])
        if hex_str in common_commands:
            common_commands[hex_str] += 1
        else:
            common_commands[hex_str] = 1
    
    # 자주 사용된 명령
    sorted_commands = sorted(common_commands.items(), key=lambda x: x[1], reverse=True)
    if sorted_commands:
        print("자주 사용된 명령:")
        for cmd, count in sorted_commands[:5]:
            print(f"  {cmd}: {count}회")
    
    # 결과 저장
    output_file = log_file.replace('.log', '_analysis.txt')
    with open(output_file, 'w') as f:
        f.write("Phocus BLE Protocol Analysis\n")
        f.write("="*60 + "\n\n")
        
        f.write("Write Commands:\n")
        for w in writes:
            f.write(f"{w['time']}: {' '.join(w['hex'])}\n")
        
        f.write("\nRead Events:\n")
        for r in reads:
            f.write(f"{r['time']}: {r['message']}\n")
        
        f.write("\nNotify Events:\n")
        for n in notifies:
            f.write(f"{n['time']}: {n['message']}\n")
    
    print(f"\n💾 상세 분석 결과 저장: {output_file}")
    print("="*60)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        analyze_phocus_log(sys.argv[1])
    else:
        print("사용법: python3 analyze_phocus_log.py <log_file>")