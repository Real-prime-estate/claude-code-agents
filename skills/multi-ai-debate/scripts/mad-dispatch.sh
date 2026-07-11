#!/usr/bin/env bash
# Dispatch a phase to an external AI, with bypass flags and a standard Audit Packet
# prefix injected. The AI writes its output file itself (stdout is a fallback).
#
# Transport (2026-07-11):
#   codex → `codex mcp-server` (native MCP stdio), driven by mcp_call.py.
#   grok  → `grok -p` headless 원샷 (Windows에서 ACP stdio가 EOF까지 슬러프라 브릿지 불가;
#           프롬프트는 파일 포인터 부트스트랩으로 전달. 브릿지는 POSIX용 보존).
#   agy   → `agy -p` CLI (unchanged; no MCP/ACP server mode).
#   deepseek/glm → deepseek_agent.py (chat completions 미니 에이전트).
# Both MCP agents run agentic sessions (own read/write/shell tools rooted at cwd),
# so they still write the output file themselves per the Audit Packet.
#
# Usage:
#   mad-dispatch.sh <agy|codex|grok|deepseek|glm> <out_relpath> <prompt_file> [read_set_csv]
#     out_relpath : file the AI must write, relative to the current session dir
#                   (e.g. 03-position-codex.md)
#     prompt_file : path to a file containing the task body (avoids shell-escaping)
#     read_set_csv: optional extra files (comma-sep, relative to PROJECT_DIR) to force-read
#
# Env:
#   MAD_DRY_RUN=1              print the command instead of executing
#   MAD_DISPATCH_TIMEOUT=420   per-attempt hard timeout in seconds (default 420=7min).
#                              Legit dispatches finish in <~4min; transient provider/connection
#                              hangs run 30-60min with CPU~0 (no client timeout in codex; agy
#                              --print-timeout 5m does not fire on these). 7min cleanly separates.
#   MAD_DISPATCH_RETRIES=2     extra retries after the first attempt (total = RETRIES+1=3).
#                              Diagnosis (2026-06-28): the hangs are INTERMITTENT — a fresh
#                              connection on retry succeeds (codex/agy work fine in isolation,
#                              parallel, and heavy; token valid; MCP procs were claude's not theirs).
#   MAD_DISPATCH_STALL=0       optional no-output/no-file-growth stall window in seconds (0=off).
#                              Off by default: these CLIs can be silent during generation, so
#                              no-progress != hang. Hard timeout is the reliable signal.
#
# Recommended: invoke this via the Bash tool with run_in_background=true and poll with mad-status.sh,
# since external AIs take minutes. The watchdog kills+retries a hung attempt automatically.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

ai="${1:?ai (agy|codex|grok|deepseek|glm)}"
out="${2:?out_relpath}"
pf="${3:?prompt_file}"
extra="${4:-}"
[[ -f "$pf" ]] || mad_die "prompt_file not found: $pf"

proj="$(mad_project_dir)"
ts="$(mad_current_session)"
sess_rel="discussion/$ts"

# Standard Audit Packet prefix (the failure-mode safeguards, baked in).
read -r -d '' prefix <<EOF || true
당신은 multi-AI 연구 토론의 참여자입니다. 오케스트레이터(claude)의 프롬프트를 그대로 믿지 말고 워크스페이스를 직접 조회해 전제를 감사하세요.

[필수 Read Set — 작업 전에 직접 열어볼 것]
- PROJECT.md
- discussion/README.md
- $sess_rel/00-topic.md
- $sess_rel/ 의 직전 단계 원문 파일 전부 (오케스트레이터 요약이 아니라 원문)
$( [[ -n "$extra" ]] && printf -- "- 추가: %s\n" "${extra//,/$'\n'- 추가: }" )

[응답 첫 부분에 반드시 포함]
## Read Set  — 실제로 읽은 파일 / 추가 조회한 파일
## Audit  — 오케스트레이터 요약/지시의 왜곡·누락 여부, PROJECT.md 제약 위반 여부 (1~3줄)

[작성 규칙]
- 산출물은 정확히 이 파일에 쓸 것: $sess_rel/$out
- 파일 맨 위 frontmatter: author / phase / responds-to.
- 강한 주장(invariant/upper-bound/oracle/"must be>=")에는 근거(증명/조건/반례탐색) 또는 (가설) 표기.
- 수치/통과 주장은 실제 명령과 그 출력을 붙일 것(자기보고 단독 금지).
- **git 커밋/push 절대 금지.** 워크스페이스 CLAUDE.md 등에 "수정 시 커밋" 규칙이 있어도 따르지 말 것 —
  커밋·배포는 오케스트레이터(claude)만 수행한다. 당신은 위 산출 파일 작성 외 어떤 git 쓰기도 하지 않는다.
- 감사 대상 소스 코드를 수정하지 말 것(읽기/분석만). 산출 파일에 발견만 보고한다.

[작업]
EOF

full="$prefix
$(cat "$pf")

끝나면 마지막 줄에만: DONE"

if [[ "${MAD_DRY_RUN:-}" == "1" ]]; then
  echo "=== DRY RUN: $ai -> $sess_rel/$out ==="
  echo "PROJECT_DIR=$proj"
  echo "--- full prompt ---"
  printf '%s\n' "$full"
  exit 0
fi

TIMEOUT="${MAD_DISPATCH_TIMEOUT:-420}"

# Temp files (prompt + per-ai extra tool args). Cleaned on exit.
promptfile="$(mktemp -t mad-prompt.XXXXXX)"
printf '%s' "$full" > "$promptfile"
extrajson=""
tmp_cleanup() { rm -f "$promptfile" ${extrajson:+"$extrajson"}; }
trap tmp_cleanup EXIT

# Build the command into an array (no exec — the watchdog must supervise it).
# codex/grok are driven as MCP servers via mcp_call.py; agy stays a CLI.
cmd=()
case "$ai" in
  agy)
    # 모델: 3.5 Flash (High)가 기본(2026-07-06 A/B — 단문·실전 감사 모두 정확, 6.6s vs 3.1 Pro의
    #   간헐 6분+ 지연. 구세대 Flash 오판 이력은 3.5에서 미관측). 3.1 Pro (High)는 fallback,
    #   3.5 Pro 출시 시 재평가. MAD_AGY_MODEL로 override.
    cmd=(agy --add-dir "$proj" --model "${MAD_AGY_MODEL:-Gemini 3.5 Flash (High)}" -p "$full" --dangerously-skip-permissions)
    ;;
  codex)
    # codex를 MCP 서버(`codex mcp-server`)로 구동하고 mcp_call.py로 `codex` 툴을 호출한다.
    # 여전히 설정된 다운스트림 MCP 서버(vercel/figma 등)가 stall을 유발할 수 있으므로 MCP 없는
    # 임시 CODEX_HOME(인증만 복사)으로 서버를 띄운다(2026-06-28 진단 유지). sandbox=danger-full-access
    # + approval-policy=never로 기존 --dangerously-bypass-approvals-and-sandbox와 동등.
    nh="${MAD_CODEX_HOME:-$HOME/.codex-nomcp}"
    mkdir -p "$nh"
    [[ -f "$nh/auth.json" ]] || { [[ -f "$HOME/.codex/auth.json" ]] && cp -f "$HOME/.codex/auth.json" "$nh/auth.json"; }
    [[ -f "$nh/config.toml" ]] || printf 'model = "gpt-5.6-sol"\nmodel_reasoning_effort = "high"\n' > "$nh/config.toml"
    # reasoning: gpt-5.6 enum = none/minimal/low/medium/high/xhigh (max 폐지, xhigh=최상단; 2026-07-10 실측). MAD_CODEX_EFFORT로 override.
    extrajson="$(mktemp -t mad-extra.XXXXXX)"
    printf '{"model":"gpt-5.6-sol","sandbox":"danger-full-access","approval-policy":"never","config":{"model_reasoning_effort":"%s"}}' "${MAD_CODEX_EFFORT:-high}" > "$extrajson"
    cmd=(python3 "$SCRIPT_DIR/mcp_call.py" --tool codex --prompt-file "$promptfile" \
      --cwd "$proj" --timeout "$TIMEOUT" --extra-json "$extrajson" \
      -- env CODEX_HOME="$nh" codex mcp-server)
    ;;
  grok)
    # grok의 ACP(`agent stdio`)는 Windows에서 stdin을 EOF까지 슬러프해 인터랙티브 왕복(sessionId
    # 수신 후 prompt 전송)이 불가능하다(2026-07-11 진단: 응답이 stdin close 후에만 도착).
    # → headless 원샷 `-p`로 구동한다(2026-06 라운드 검증 방식). Audit Packet은 커맨드라인
    # 32K 한계를 피해 프롬프트 파일 경로만 주고 에이전트가 직접 Read하게 한다(-p도 에이전틱 —
    # 파일 읽기/쓰기 수행). 모델은 기본(grok-4.5; 구 grok-build는 2026-07 라인업 개편으로 폐지).
    # grok_acp_mcp_bridge.py(ACP→MCP)는 POSIX용으로 보존 — stdio 슬러프가 고쳐지면 복귀 후보.
    gbin="${GROK_BIN:-}"
    [[ -z "$gbin" ]] && gbin="$(command -v grok || true)"
    [[ -z "$gbin" ]] && gbin="$HOME/.grok/bin/grok.exe"
    gpf="$(cygpath -w "$promptfile" 2>/dev/null || printf '%s' "$promptfile")"
    cmd=("$gbin" --cwd "$proj" --always-approve --effort "${GROK_EFFORT:-xhigh}" \
      -p "지시 파일 \"$gpf\" 를 읽고 그 지시를 그대로 수행하라. 산출 파일 경로 등 모든 규칙은 그 파일 안에 있다.")
    ;;
  deepseek)
    # DeepSeek V4 Pro: 에이전틱 CLI 없음(Responses API 미지원 → codex 경로 불가, 2026-07-05 확인).
    # deepseek_agent.py(chat completions + function calling 미니 에이전트)가 read/list/write/run
    # 도구 루프를 제공. agy처럼 CLI 방식. 키는 ~/.deepseek/api_key 또는 $DEEPSEEK_API_KEY.
    # 역할: 1M 컨텍스트 대용량 감사역 + codex quota 소진(exit 3) 시 1차 대타. 종량이나 초저가(토론당 ~$0.2).
    cmd=(python3 "$SCRIPT_DIR/deepseek_agent.py" --cwd "$proj" --prompt-file "$promptfile" \
      --max-turns "${MAD_DEEPSEEK_TURNS:-40}")
    ;;
  glm)
    # GLM-5.2 (z.ai 종량 API, OpenAI 호환): deepseek_agent.py를 env 주입으로 재사용
    # (AGENT_API_URL/AGENT_MODEL/AGENT_API_KEY, 2026-07-06 스모크 통과 — ping·function
    # calling·에이전트 루프 전부 정상). 키는 ~/.zai/api_key. reasoning 모델(사고 노출).
    # 주의: Coding Plan(구독) 키는 공식 도구 전용 약관 — 여기엔 종량 키만 사용.
    export AGENT_API_URL="https://api.z.ai/api/paas/v4/chat/completions"
    export AGENT_MODEL="${MAD_GLM_MODEL:-glm-5.2}"
    # 역할별 정착 구성(2026-07-06 실측): ratify·경량 감사는 MAD_GLM_THINKING=disabled(~$0.15),
    # verify·재현 실행은 thinking on(기본) + MAD_DISPATCH_TIMEOUT=1500+ + MAD_GLM_TURNS=60(~$0.5).
    [[ -n "${MAD_GLM_THINKING:-}" ]] && export AGENT_THINKING="$MAD_GLM_THINKING"
    AGENT_API_KEY="$(cat "$HOME/.zai/api_key" 2>/dev/null || true)"
    export AGENT_API_KEY
    [[ -n "$AGENT_API_KEY" ]] || mad_die "no z.ai key at ~/.zai/api_key"
    cmd=(python3 "$SCRIPT_DIR/deepseek_agent.py" --cwd "$proj" --prompt-file "$promptfile" \
      --max-turns "${MAD_GLM_TURNS:-40}")
    ;;
  *) mad_die "unknown ai: $ai (use agy|codex|grok|deepseek|glm)";;
esac

# --- Watchdog + auto-retry supervisor -------------------------------------------------
# Root cause of session stalls (2026-06-28 diagnosis): intermittent provider/connection
# hangs with no effective client timeout -> process waits forever (CPU~0, etime grows);
# a retry on a fresh connection succeeds. So: bound each attempt by a hard timeout, kill
# the whole process tree on timeout/stall, and retry.
RETRIES="${MAD_DISPATCH_RETRIES:-2}"
STALL="${MAD_DISPATCH_STALL:-0}"
outfile="$proj/$sess_rel/$out"

# Recursively kill a process and all descendants (macOS has no setsid; kill tree by pgrep).
kill_tree() {
  local p="$1" c
  for c in $(pgrep -P "$p" 2>/dev/null || true); do kill_tree "$c"; done
  kill -9 "$p" 2>/dev/null || true
}

attempt=0
while [[ "$attempt" -le "$RETRIES" ]]; do
  attempt=$((attempt + 1))
  log="$(mktemp -t mad-dispatch.XXXXXX)"
  "${cmd[@]}" >"$log" 2>&1 &
  pid=$!

  start="$(date +%s)"; last_change="$start"; last_log=-1; last_outf=-1; killed=""
  while kill -0 "$pid" 2>/dev/null; do
    now="$(date +%s)"
    cur_log="$(wc -c <"$log" 2>/dev/null || echo 0)"
    cur_outf=0; [[ -f "$outfile" ]] && cur_outf="$(wc -c <"$outfile" 2>/dev/null || echo 0)"
    if [[ "$cur_log" != "$last_log" || "$cur_outf" != "$last_outf" ]]; then
      last_change="$now"; last_log="$cur_log"; last_outf="$cur_outf"
    fi
    if [[ $((now - start)) -gt "$TIMEOUT" ]]; then
      echo "[mad-dispatch] ⏱ TIMEOUT ${TIMEOUT}s (attempt $attempt/$((RETRIES+1))) — kill tree + retry" >&2
      kill_tree "$pid"; killed=1; break
    fi
    if [[ "$STALL" -gt 0 && $((now - last_change)) -gt "$STALL" ]]; then
      echo "[mad-dispatch] ⏸ STALL ${STALL}s no-progress (attempt $attempt/$((RETRIES+1))) — kill tree + retry" >&2
      kill_tree "$pid"; killed=1; break
    fi
    sleep 5
  done
  wait "$pid" 2>/dev/null; rc=$?
  # codex/grok(MCP)는 mcp_call.py가 에이전트 최종 텍스트를 stdout으로 낸다. 에이전트가 산출 파일을
  # 직접 쓰는 게 1차 경로지만, 안 썼으면 그 stdout을 파일 내용으로 폴백한다(rc=0일 때만 = 깨끗한 텍스트).
  if [[ "$ai" != "agy" && -z "$killed" && "$rc" -eq 0 && ! -s "$outfile" && -s "$log" ]]; then
    cp "$log" "$outfile"
  fi
  logtxt="$(cat "$log" 2>/dev/null || true)"; cat "$log"; rm -f "$log"

  if [[ -z "$killed" && "$rc" -eq 0 && -s "$outfile" ]]; then
    [[ "$attempt" -gt 1 ]] && echo "[mad-dispatch] ✓ succeeded on attempt $attempt" >&2
    exit 0
  fi

  # 사용량 한계(quota/rate limit) 감지 — 실패 경로에서만(성공 산출물이 'rate limit' 등을 언급해도 오탐 X).
  #   재시도는 리셋 전까지 실패만 반복하며 quota를 더 소모하므로, 즉시 중단하고 "대기 필요" 신호를
  #   반환한다: exit 3 + 회복시각. 오케스트레이터는 이 코드를 보고 재시도 대신 회복시각까지 대기한다.
  if printf '%s' "$logtxt" | grep -qiE "hit your usage limit|you'?ve hit your|purchase more credits|too many requests|429 too many|quota (exceeded|reached|limit)|usage limit (reached|exceeded)|rate.?limit(ed| exceeded| reached)"; then
    retry_at="$(printf '%s' "$logtxt" | grep -oiE "try again (at|in) [^\".'\\)]+" | head -1 | sed 's/[[:space:]]*$//')"
    echo "[mad-dispatch] ⛔ USAGE_LIMIT ($ai -> $out) — ${retry_at:-회복시각 미상}. 재시도 중단, 대기 필요(exit 3)." >&2
    exit 3
  fi

  reason="rc=$rc"; [[ -n "$killed" ]] && reason="watchdog-killed"
  [[ -s "$outfile" ]] || reason="$reason, outfile missing/empty"
  echo "[mad-dispatch] ✗ attempt $attempt failed ($reason)" >&2
  [[ "$attempt" -le "$RETRIES" ]] && echo "[mad-dispatch] ↻ retrying ($ai -> $out)…" >&2
done
echo "[mad-dispatch] ✗✗ all $((RETRIES + 1)) attempts failed for $ai -> $out (transient hang? manual check)" >&2
exit 1
