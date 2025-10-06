#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/common.sh"

if ! command -v swift >/dev/null; then
  echo "swift toolchain not found" >&2
  exit 1
fi

if swift --help | grep -q "format"; then
  swift format --in-place --recursive "$PROJECT_ROOT/Sources" "$PROJECT_ROOT/Tests"
else
  if ! command -v swift-format >/dev/null; then
    echo "swift-format CLI not installed; see README for installation instructions" >&2
    exit 1
  fi
  swift-format format --parallel --in-place --recursive "$PROJECT_ROOT/Sources" "$PROJECT_ROOT/Tests"
fi
