#!/bin/zsh
# Creates a signed archive; never uploads or accepts agreements.
set -euo pipefail
cd "${0:A:h:h}"
python3 scripts/check-config.py --signing
command -v xcodegen >/dev/null || { echo "xcodegen이 필요해요"; exit 1; }
xcodegen generate --quiet
xcodebuild -project HanjuStack.xcodeproj -scheme HanjuStack -configuration Release \
  -destination 'generic/platform=macOS' -archivePath build/HanjuStack.xcarchive \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO -allowProvisioningUpdates archive
echo "Xcode Organizer에서 archive를 검증한 후 App Store Connect 배포를 진행하세요."
