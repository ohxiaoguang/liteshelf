#!/bin/bash
set -euo pipefail
# Use the runner's installed default Xcode; never download a guessed version.
xcodebuild -version
sdk=$(xcrun --sdk macosx --show-sdk-version)
major=${sdk%%.*}
if (( major < 14 )); then
  echo "error: A macOS 14 or newer SDK is required; found $sdk." >&2
  exit 1
fi
if (( major < 27 )); then
  echo "::warning::macOS SDK $sdk builds a compatible macOS 14+ app, but cannot validate macOS 27 SDK behavior."
fi
