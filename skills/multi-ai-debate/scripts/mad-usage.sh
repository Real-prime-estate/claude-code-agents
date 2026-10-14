#!/usr/bin/env bash
# codex exec --json 의 JSONL 로그에서 토큰 사용량을 집계한다.
#   사용: mad-usage.sh <jsonl-file...>   또는   codex exec --json … | mad-usage.sh
# turn.completed 이벤트의 usage: input_tokens / cached_input_tokens /
#   cache_write_input_tokens / output_tokens / reasoning_output_tokens
set -euo pipefail
python3 - "$@" <<'PY'
import json, sys, pathlib
srcs = [pathlib.Path(a).read_text().splitlines() for a in sys.argv[1:]] or [sys.stdin.read().splitlines()]
tot = {}
turns = 0
for lines in srcs:
    for ln in lines:
        ln = ln.strip()
        if not ln.startswith("{"):
            continue
        try:
            d = json.loads(ln)
        except Exception:
            continue
        if d.get("type") != "turn.completed":
            continue
        turns += 1
        for k, v in (d.get("usage") or {}).items():
            tot[k] = tot.get(k, 0) + int(v or 0)
if not turns:
    print("turn.completed 이벤트 없음 (--json 으로 실행했는지 확인)"); raise SystemExit(1)
inp = tot.get("input_tokens", 0); cac = tot.get("cached_input_tokens", 0)
out = tot.get("output_tokens", 0); rea = tot.get("reasoning_output_tokens", 0)
print(f"턴 {turns}")
print(f"  입력    {inp:>9,}  (캐시 적중 {cac:,} = {cac/inp*100:.1f}%)" if inp else "  입력 0")
print(f"  출력    {out:>9,}  (그중 추론 {rea:,} = {rea/out*100:.1f}%)" if out else "  출력 0")
print(f"  비캐시 입력 {inp-cac:>6,}   ← 실질 과금·할당량 영향분")
PY
