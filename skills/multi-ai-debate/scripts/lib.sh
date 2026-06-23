#!/usr/bin/env bash
# Shared helpers for multi-ai-debate scripts.
# Designed to be standalone so the script set can later graduate into a CLI.
set -euo pipefail

# Resolve the project dir = nearest ancestor (from PWD) containing PROJECT.md.
# Override with MAD_PROJECT_DIR.
mad_project_dir() {
  if [[ -n "${MAD_PROJECT_DIR:-}" ]]; then printf '%s\n' "$MAD_PROJECT_DIR"; return; fi
  local d="$PWD"
  while [[ "$d" != "/" ]]; do
    [[ -f "$d/PROJECT.md" ]] && { printf '%s\n' "$d"; return; }
    d="$(dirname "$d")"
  done
  # fallback: PWD
  printf '%s\n' "$PWD"
}

mad_disc_dir() {
  if [[ -n "${MAD_DISCUSSION_DIR:-}" ]]; then printf '%s\n' "$MAD_DISCUSSION_DIR"; return; fi
  printf '%s/discussion\n' "$(mad_project_dir)"
}

mad_current_session() {
  local disc; disc="$(mad_disc_dir)"
  [[ -f "$disc/.current-session" ]] || { echo "ERROR: no .current-session in $disc (run mad-new first)" >&2; return 1; }
  cat "$disc/.current-session"
}

mad_session_path() {
  printf '%s/%s\n' "$(mad_disc_dir)" "$(mad_current_session)"
}

mad_die() { echo "ERROR: $*" >&2; exit 1; }
