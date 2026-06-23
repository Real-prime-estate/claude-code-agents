#!/usr/bin/env bash
# Create a new debate session: discussion/<YYYY-MM-DD_HHMMSS>/, seed 00-topic.md, set .current-session.
# Usage: mad-new.sh "<topic title>"
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

title="${1:-untitled debate}"
disc="$(mad_disc_dir)"
ts="$(date +%Y-%m-%d_%H%M%S)"
sess="$disc/$ts"
mkdir -p "$sess"
printf '%s\n' "$ts" > "$disc/.current-session"

cat > "$sess/00-topic.md" <<EOF
---
author: claude (orchestrator)
phase: topic
responds-to: PROJECT.md
---

# 의제 — $title

## 배경

(무엇을 결정해야 하는가. 고정 조건/제약을 명시.)

## 결정해야 할 것

1.
2.

## 평가 관점 (각 AI가 다룰 것)

-

## 프로토콜

topic → position → critique → [spec-review(Gate1)] → synthesis → ratify(Gate2) → decision.
고위험 산출물에는 Claim Ledger 필수. 자세한 규칙은 discussion/README.md 또는 이 skill의 SKILL.md 참조.
EOF

echo "session: $ts"
echo "topic:   $sess/00-topic.md"
