#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/TYScreenShotTool.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/DerivedData"
SCHEME="TYScreenShotTool_Release"
CONFIGURATION="Release"

mkdir -p "$DERIVED_DATA_PATH"

exec xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build
