#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/TYScreenShotTool.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/DerivedData"
ARCHIVE_DIR="$ROOT_DIR/archived"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ARCHIVE_DIR/TYScreenShotTool.xcarchive}"
SCHEME="TYScreenShotTool"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-platform=macOS}"

mkdir -p "$DERIVED_DATA_PATH"
mkdir -p "$ARCHIVE_DIR"

exec xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -archivePath "$ARCHIVE_PATH"
