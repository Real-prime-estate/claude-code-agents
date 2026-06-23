#!/usr/bin/env bash
# Show current session files + running external-AI processes (poll without relying on notifications).
# Usage: mad-status.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

sess="$(mad_session_path)"
echo "=== session: $(mad_current_session) ==="
echo "--- files ---"
ls -1 "$sess" 2>/dev/null | sort || true
echo "--- running external AI procs ---"
pgrep -af 'codex exec|codex-aarch64|agy ' 2>/dev/null | grep -v 'mad-status' || echo "(none)"
echo "--- active uv/pytest/mypy (codex may be running checks) ---"
pgrep -af 'uv run|pytest|mypy|ruff' 2>/dev/null | grep -v 'mad-status' || echo "(none)"
