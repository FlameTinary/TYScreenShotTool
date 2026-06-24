#!/bin/zsh
#
# 测试运行脚本
# 用法: ./scripts/test.sh [选项]
#
# 选项:
#   -c <config>     构建配置 (Debug/Release, 默认: Debug)
#   -d <dest>       destination (默认: platform=macOS)
#   -t <test-class> 运行指定测试类 (如 SharedTests)
#   -m <method>     运行指定测试方法 (如 testExample)
#   -s              跳过构建，只运行测试 (需要已有测试产物)
#   -v              详细输出 (显示所有测试日志)
#   -h              显示此帮助信息
#

set -euo pipefail

SCRIPT_NAME="${0##*/}"

# ---------- 路径 ----------
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/TYScreenShotTool.xcodeproj"
SCHEME="TYScreenShotTool"
DERIVED_DATA_PATH="$ROOT_DIR/DerivedDataTests"
TEST_TARGET="TYScreenShotToolTests"

# ---------- 默认值 ----------
CONFIGURATION="Debug"
DESTINATION="platform=macOS"
TEST_CLASS=""
TEST_METHOD=""
SKIP_BUILD=false
VERBOSE=false

# ---------- 参数解析 ----------
usage() {
  cat <<EOF
用法: $SCRIPT_NAME [选项]

选项:
  -c <config>     构建配置 (Debug/Release, 默认: Debug)
  -d <dest>       destination (默认: platform=macOS)
  -t <test-class> 运行指定测试类 (如 SharedTests)
  -m <method>     运行指定测试方法 (如 testExample)
  -s              跳过构建，只运行测试 (需要已有测试产物)
  -v              详细输出 (显示所有测试日志)
  -h              显示此帮助信息
EOF
  exit 0
}

while getopts "c:d:t:m:svh" opt; do
  case "$opt" in
    c) CONFIGURATION="$OPTARG" ;;
    d) DESTINATION="$OPTARG" ;;
    t) TEST_CLASS="$OPTARG" ;;
    m) TEST_METHOD="$OPTARG" ;;
    s) SKIP_BUILD=true ;;
    v) VERBOSE=true ;;
    h) usage ;;
    *) usage ;;
  esac
done

# ---------- 构建 ----------
if ! $SKIP_BUILD; then
  echo "🔨 编译 ($CONFIGURATION)..."
  mkdir -p "$DERIVED_DATA_PATH"

  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    build-for-testing

  echo "✅ 编译完成"
  echo ""
fi

# ---------- 组装测试标识符 ----------
if [[ -n "$TEST_CLASS" ]]; then
  TEST_IDENTIFIER="${TEST_TARGET}/${TEST_CLASS}"
  if [[ -n "$TEST_METHOD" ]]; then
    TEST_IDENTIFIER="${TEST_IDENTIFIER}/${TEST_METHOD}"
  fi
else
  TEST_IDENTIFIER="$TEST_TARGET"
fi

# ---------- 运行测试 ----------
echo "🧪 运行测试: $TEST_IDENTIFIER"
echo "═══════════════════════════════════════════════════"

XCODEBUILD_OPTS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -only-testing "$TEST_IDENTIFIER"
  test-without-building
)

if $VERBOSE; then
  # 详细模式: 显示完整 xcodebuild 输出
  xcodebuild "${XCODEBUILD_OPTS[@]}"
  RESULT=$?
else
  # 默认模式: 仅显示测试结果摘要
  mkdir -p "$ROOT_DIR/tmp"
  LOG_FILE=$(mktemp "${ROOT_DIR}/tmp/tyscreenshot-test-XXXXXX.log")
  trap "rm -f '$LOG_FILE'" EXIT

  set +e
  xcodebuild "${XCODEBUILD_OPTS[@]}" > "$LOG_FILE" 2>&1
  RESULT=$?
  set -e

  # 提取关键结果
  if grep -q "TEST SUCCEEDED" "$LOG_FILE"; then
    echo "✅ 测试通过"
  elif grep -q "TEST FAILED" "$LOG_FILE"; then
    echo "❌ 测试失败"
  fi

  # 显示测试计数
  grep -E "(Test Suite .* (started|passed|failed))|(^\t.*\[.*\])" "$LOG_FILE" || true

  # 显示失败详情
  if [[ $RESULT -ne 0 ]]; then
    echo ""
    echo "📋 失败详情:"
    grep -A2 "FAILED\|error:" "$LOG_FILE" | head -40 || true
  fi

  echo ""
  echo "📄 完整日志: $LOG_FILE"
fi

exit $RESULT
