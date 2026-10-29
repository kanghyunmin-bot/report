#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
python3 scripts/check-config.py
node tests/time-migration.cjs
node tests/save-queue.cjs
mkdir -p build/checks
xcrun swiftc -typecheck Shared/*.swift Sources/*.swift -framework Cocoa -framework WebKit -framework WidgetKit -framework CoreText
xcrun swiftc -parse-as-library -typecheck Shared/*.swift Widget/HanjuWidget.swift -framework SwiftUI -framework WidgetKit -framework AppIntents
xcrun swiftc Shared/HanjuStore.swift tests/shared-store.swift -o build/checks/shared-store
build/checks/shared-store
