#!/usr/bin/env python3
"""
BLE 패킷 분석 도구
PacketLogger나 Console 로그에서 BLE 통신 패턴 추출
"""

import re
import sys
import json
from datetime import datetime
from collections import defaultdict, OrderedDict

class BLEAnalyzer:
    def __init__(self):
        self.commands = []
        self.services = set()
        self.characteristics = {}
        self.write_sequence = []
        
    def parse_packet_logger(self, line):
        """PacketLogger 형식 파싱"""
        # ATT Write Request 패턴
        write_pattern = r'ATT Write.*Handle:\s*0x([0-9A-Fa-f]+).*Value:\s*([0-9A-Fa-f\s]+)'
        match = re.search(write_pattern, line)
        if match:
            handle = match.group(1)
            value = match.group(2).replace(' ', '')
            return {'type': 'write', 'handle': handle, 'value': value}
        
        # Service Discovery 패턴
        service_pattern = r'Service UUID:\s*([0-9A-Fa-f]{4})'
        match = re.search(service_pattern, line)
        if match:
            self.services.add(match.group(1))
            
        # Characteristic 패턴
        char_pattern = r'Characteristic.*UUID:\s*([0-9A-Fa-f]{4}).*Handle:\s*0x([0-9A-Fa-f]+)'
        match = re.search(char_pattern, line)
        if match:
            uuid = match.group(1)
            handle = match.group(2)
            self.characteristics[handle] = uuid
            
        return None
    
    def parse_console_log(self, line):
        """Console 로그 형식 파싱"""
        # hex 데이터 패턴
        hex_pattern = r'\[([0-9A-Fa-f]{2}(?:\s+[0-9A-Fa-f]{2})*)\]'
        match = re.search(hex_pattern, line)
        if match and ('write' in line.lower() or 'fff' in line.lower()):
            hex_data = match.group(1).replace(' ', '')
            return {'type': 'data', 'value': hex_data}
        
        # FFF 서비스/특성 패턴
        fff_pattern = r'FFF([0-9A-Fa-f])'
        matches = re.findall(fff_pattern, line, re.I)
        for m in matches:
            self.services.add(f'FFF{m}')
            
        return None
    
    def analyze_file(self, filepath):
        """파일 분석"""
        print(f"📖 파일 분석 중: {filepath}")
        
        with open(filepath, 'r', errors='ignore') as f:
            for line_num, line in enumerate(f, 1):
                # PacketLogger 형식 시도
                result = self.parse_packet_logger(line)
                if result and result['type'] == 'write':
                    # Handle을 UUID로 변환
                    handle = result['handle']
                    uuid = self.characteristics.get(handle, f'Handle_{handle}')
                    
                    self.write_sequence.append({
                        'line': line_num,
                        'uuid': uuid,
                        'handle': handle,
                        'value': result['value'],
                        'bytes': self.hex_to_bytes(result['value'])
                    })
                
                # Console 로그 형식 시도
                result = self.parse_console_log(line)
                if result and result['type'] == 'data':
                    self.commands.append({
                        'line': line_num,
                        'value': result['value'],
                        'bytes': self.hex_to_bytes(result['value'])
                    })
    
    def hex_to_bytes(self, hex_string):
        """Hex 문자열을 바이트 배열로 변환"""
        try:
            # 공백 제거
            hex_string = hex_string.replace(' ', '').replace('0x', '')
            # 2자리씩 분리
            bytes_list = []
            for i in range(0, len(hex_string), 2):
                if i+1 < len(hex_string):
                    bytes_list.append(int(hex_string[i:i+2], 16))
            return bytes_list
        except:
            return []
    
    def interpret_command(self, bytes_data):
        """명령 바이트 해석"""
        if not bytes_data:
            return "Unknown"
        
        # 알려진 명령 패턴
        known_commands = {
            (0x01, 0x01, 0x00): "WiFi Power ON",
            (0x02, 0x00, 0x01): "WiFi Enable",
            (0x04, 0x01, 0x00): "AP Mode Enable",
            (0x0A, 0x00, 0x01): "Remote Control",
            (0x0B, 0x00, 0x01): "Broadcast ON",
            (0x0C, 0x00, 0x01): "Server Start",
            (0x0D, 0x01, 0x00): "SSID Broadcast",
            (0x0E, 0x00, 0x01): "Accept Connection",
            (0x0F, 0x01, 0x00): "Phocus Mode",
        }
        
        # 첫 3바이트로 매칭
        if len(bytes_data) >= 3:
            key = tuple(bytes_data[:3])
            if key in known_commands:
                return known_commands[key]
        
        # 첫 바이트로 추측
        if bytes_data[0] == 0x01:
            return "Power/Init Command"
        elif bytes_data[0] == 0x02:
            return "Enable Command"
        elif bytes_data[0] == 0x04:
            return "Mode Command"
        elif bytes_data[0] == 0x0D:
            return "SSID Command"
        
        return f"Command 0x{bytes_data[0]:02X}"
    
    def print_report(self):
        """분석 보고서 출력"""
        print("\n" + "="*60)
        print("📊 BLE 통신 분석 보고서")
        print("="*60)
        
        # 발견된 서비스
        if self.services:
            print("\n🔷 발견된 BLE Services:")
            for service in sorted(self.services):
                print(f"  • {service}")
        
        # Characteristic 매핑
        if self.characteristics:
            print("\n📍 Characteristic 매핑:")
            for handle, uuid in sorted(self.characteristics.items()):
                print(f"  • Handle 0x{handle} → UUID {uuid}")
        
        # Write 시퀀스
        if self.write_sequence:
            print(f"\n📝 Write 명령 시퀀스 ({len(self.write_sequence)}개):")
            for i, cmd in enumerate(self.write_sequence[:20], 1):
                interpretation = self.interpret_command(cmd['bytes'])
                print(f"\n  [{i}] {cmd['uuid']} (Handle 0x{cmd['handle']})")
                print(f"      Hex: {cmd['value'][:40]}...")
                print(f"      Bytes: {cmd['bytes'][:10]}")
                print(f"      해석: {interpretation}")
        
        # 일반 명령 데이터
        if self.commands and not self.write_sequence:
            print(f"\n📦 발견된 데이터 패턴 ({len(self.commands)}개):")
            for i, cmd in enumerate(self.commands[:10], 1):
                interpretation = self.interpret_command(cmd['bytes'])
                print(f"\n  [{i}] 라인 {cmd['line']}")
                print(f"      Hex: {cmd['value'][:40]}...")
                print(f"      Bytes: {cmd['bytes'][:10]}")
                print(f"      해석: {interpretation}")
        
        # Swift 코드 생성
        self.generate_swift_code()
    
    def generate_swift_code(self):
        """Swift 코드 템플릿 생성"""
        print("\n" + "="*60)
        print("🔧 Swift 코드 템플릿")
        print("="*60)
        
        if self.write_sequence:
            print("\n// BluetoothCameraManager.swift에 추가할 코드")
            print("private func activateWiFiFromCapture() async throws {")
            print("    logger.log(\"🔄 캡처된 시퀀스로 WiFi 활성화\")")
            print("    ")
            print("    let capturedCommands: [(String, Data)] = [")
            
            for cmd in self.write_sequence[:10]:
                interpretation = self.interpret_command(cmd['bytes'])
                bytes_str = ', '.join([f"0x{b:02X}" for b in cmd['bytes'][:10]])
                print(f"        (\"{interpretation}\", Data([{bytes_str}])),")
            
            print("    ]")
            print("    ")
            print("    guard let characteristic = wifiControlCharacteristic else {")
            print("        throw WiFiError.characteristicNotFound")
            print("    }")
            print("    ")
            print("    for (description, data) in capturedCommands {")
            print("        logger.log(\"📤 전송: \\(description)\")")
            print("        peripheral?.writeValue(data, for: characteristic, type: .withResponse)")
            print("        try await Task.sleep(nanoseconds: 200_000_000) // 0.2초")
            print("    }")
            print("}")

def main():
    if len(sys.argv) < 2:
        print("사용법: python3 analyze_packets.py <로그파일>")
        print("예: python3 analyze_packets.py ble_capture.log")
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    analyzer = BLEAnalyzer()
    
    try:
        analyzer.analyze_file(filepath)
        analyzer.print_report()
        
        # JSON 형식으로 저장
        output_file = filepath.replace('.log', '_analysis.json')
        with open(output_file, 'w') as f:
            json.dump({
                'services': list(analyzer.services),
                'characteristics': analyzer.characteristics,
                'write_sequence': analyzer.write_sequence[:20],
                'commands': analyzer.commands[:20]
            }, f, indent=2)
        
        print(f"\n💾 분석 결과 저장: {output_file}")
        
    except FileNotFoundError:
        print(f"❌ 파일을 찾을 수 없습니다: {filepath}")
    except Exception as e:
        print(f"❌ 분석 중 오류: {e}")

if __name__ == "__main__":
    main()