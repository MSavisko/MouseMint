#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p .build/module-cache
xcrun swiftc -module-cache-path .build/module-cache Sources/BatteryStatus.swift Sources/BluetoothBatteryReader.swift Sources/ConnectionMode.swift Tests/BatteryTests.swift -o .build/battery-tests
.build/battery-tests
xcrun swiftc -module-cache-path .build/module-cache \
  Sources/BatteryStatus.swift Sources/BluetoothBatteryReader.swift Sources/ConnectionMode.swift \
  Sources/MouseReader.swift Sources/ReceiverReader.swift Sources/NaturalScrolling.swift \
  Tests/NaturalScrollingTests.swift -o .build/natural-scrolling-tests
.build/natural-scrolling-tests
