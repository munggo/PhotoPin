#!/bin/bash

echo "================================================"
echo "🎯 STEP 1: Phocus 앱 BLE 캡처 준비"
echo "================================================"
echo ""

echo "📱 준비 사항:"
echo "1. iPhone에 Phocus 2 앱이 설치되어 있는지 확인"
echo "2. iPhone을 Mac에 USB로 연결"
echo "3. 카메라 전원 켜기"
echo ""

echo "🔧 Mac 설정:"
echo "다음 명령을 터미널에서 실행하세요:"
echo ""
echo "# Bluetooth 디버그 로깅 활성화 (sudo 권한 필요)"
echo "sudo defaults write com.apple.bluetooth BluetoothDebugEnabled -bool true"
echo "sudo defaults write com.apple.bluetooth PacketLoggerEnabled -bool true"
echo ""

echo "📊 Console 앱 실행:"
echo "1. Console 앱 열기:"
open /System/Applications/Utilities/Console.app

echo "2. 왼쪽 사이드바에서 iPhone 선택"
echo "3. 검색창에 필터 설정:"
echo "   - 'bluetooth' 또는"
echo "   - 'phocus' 또는"
echo "   - 'hasselblad'"
echo ""

echo "💡 팁:"
echo "- Console 창을 Clear 하고 시작하면 깔끔합니다"
echo "- Action > Include Info/Debug Messages 체크"
echo "- 로그가 너무 빠르면 Pause 버튼 활용"
echo ""

echo "준비가 완료되면 Enter를 누르세요..."
read -p ""

echo ""
echo "✅ 준비 완료!"
echo "다음 단계: Phocus 앱으로 카메라 연결하면서 로그 관찰"
echo ""
echo "📝 체크리스트:"
echo "[ ] Console 앱이 열려있고 iPhone이 선택됨"
echo "[ ] 필터가 설정됨 (bluetooth/phocus)"
echo "[ ] 카메라 전원이 켜져있음"
echo "[ ] Phocus 앱 실행 준비됨"