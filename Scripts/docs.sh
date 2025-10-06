#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/common.sh"

OUTPUT_DIR=${1:-"$PROJECT_ROOT/.build/docc"}
HOSTING_BASE_PATH=${2:-SwiftLLDP}

mkdir -p "$OUTPUT_DIR"

swift package generate-documentation \
  --target SwiftLLDP \
  --output-path "$OUTPUT_DIR" \
  --transform-for-static-hosting \
  --hosting-base-path "$HOSTING_BASE_PATH"

echo "DocC archive available at $OUTPUT_DIR"
