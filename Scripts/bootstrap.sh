#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/common.sh"
HOOK_DIR="$PROJECT_ROOT/.git/hooks"

if [ ! -d "$HOOK_DIR" ]; then
  echo "Git hooks directory not found; are you inside a git repository?" >&2
  exit 1
fi

cat <<'HOOK' > "$HOOK_DIR/pre-commit"
#!/usr/bin/env bash
set -euo pipefail
Scripts/lint.sh
Scripts/test.sh --skip-build
HOOK
chmod +x "$HOOK_DIR/pre-commit"

echo "Pre-commit hook installed."
