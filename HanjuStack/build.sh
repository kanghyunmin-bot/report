#!/bin/zsh
# 한 주 쌓기: Xcode로 앱 + 위젯을 빌드해요. (위젯 버튼이 앱을 열지 않고 바로 동작하려면 Xcode 빌드가 필요해요)
set -euo pipefail
cd "${0:A:h}"
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Xcode가 필요해요. App Store에서 Xcode 설치 → 한 번 실행 → 아래 명령 후 다시 시도:"
  echo "  sudo xcode-select -s /Applications/Xcode.app"
  exit 1
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen이 필요해요:  brew install xcodegen"
  exit 1
fi
xcodegen generate --quiet
xcodebuild -project HanjuStack.xcodeproj -target HanjuStack -configuration Release \
  SYMROOT="$PWD/build" ONLY_ACTIVE_ARCH=YES -quiet
echo "완료: $PWD/build/Release/HanjuStack.app"
