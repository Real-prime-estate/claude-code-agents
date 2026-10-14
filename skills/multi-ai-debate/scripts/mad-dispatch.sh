#!/usr/bin/env bash
# Dispatch a phase to an external AI, with bypass flags and a standard Audit Packet
# prefix injected. The AI writes its output file itself (stdout is a fallback).
#
# Transport (2026-07-03):
#   codex    → `codex exec --json` (CLI 직접 호출; usage 관측 + resume 가능).
#   agy      → `agy --model … -p` (CLI).
#   deepseek → deepseek_agent.py (chat completions + function calling 미니 에이전트).
#   grok     → `grok -m grok-4.7 --reasoning-effort xhigh -p` CLI (2026-10-06 재합류). **일회용 복제본에서
#              실행**한다 — grok 헤드리스는 권한 모드(plan·dontAsk 포함)와 무관하게 셸·파일 쓰기를 한다
#              (2026-10-06 실측). 복제본에 쓴 산출 파일을 세션으로 옮기고, 없으면 stdout으로 폴백.
#   agy   → `agy -p` CLI (unchanged; no MCP/ACP server mode).
# Agentic sessions (own read/write/shell tools rooted at cwd) write the output file themselves
# per the Audit Packet.
#
# Usage:
#   mad-dispatch.sh <agy|codex|deepseek|grok> <out_relpath> <prompt_file> [read_set_csv]
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

ai="${1:?ai (agy|codex|deepseek|grok)}"
out="${2:?out_relpath}"
pf="${3:?prompt_file}"
extra="${4:-}"
[[ -f "$pf" ]] || mad_die "prompt_file not found: $pf"

proj="$(mad_project_dir)"
ts="$(mad_current_session)"
sess_rel="discussion/$ts"

# 작업 맥락 인라인 동봉 (2026-07-26 사용자 규칙): 세션 00-topic.md 전문을 프롬프트에
# 직접 포함 — read-set 참조만으로는 맥락 누락 위험(빈 스텁·미열람). MAD_CONTEXT_FILE로
# override 가능. 오케스트레이터는 디스패치 전 00-topic.md에 맥락(목적·이력·수치·결정
# 대상·대안)을 채울 의무가 있다(mad-new.sh 스텁 상태로 두지 말 것).
ctx_file="$proj/$sess_rel/00-topic.md"
[[ -n "${MAD_CONTEXT_FILE:-}" && -f "${MAD_CONTEXT_FILE}" ]] && ctx_file="$MAD_CONTEXT_FILE"
ctx=""
[[ -f "$ctx_file" ]] && ctx="$(cat "$ctx_file")"

# Standard Audit Packet prefix (the failure-mode safeguards, baked in).
read -r -d '' prefix <<EOF || true
당신은 multi-AI 연구 토론의 참여자입니다. 오케스트레이터(claude)의 프롬프트를 그대로 믿지 말고 워크스페이스를 직접 조회해 전제를 감사하세요.

$( [[ -n "$ctx" ]] && printf '[작업 맥락 — 세션 컨텍스트 전문(오케스트레이터 작성). 작업 이해의 기준선으로 쓰되, 수치·주장은 아래 Read Set 원문으로 재검증하라]\n%s\n' "$ctx" )

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
grokclone=""
tmp_cleanup() {
  rm -f "$promptfile" ${extrajson:+"$extrajson"}
  # grok 일회용 복제본은 휴지통으로 옮긴다(영구 삭제 대신 — 사용자 규율).
  if [[ -n "$grokclone" && -d "$grokclone" && ! -L "$grokclone" ]]; then
    local gparent; gparent="$(dirname "$grokclone")"
    mv "$gparent" "$HOME/.Trash/$(basename "$gparent")" 2>/dev/null || true
  fi
}
trap tmp_cleanup EXIT

# Build the command into an array (no exec — the watchdog must supervise it).
# 전부 CLI/API 직접 호출로 구동한다(2026-09-07 방침). MCP 경로 미사용.
cmd=()
case "$ai" in
  agy)
    # 모델: Gemini 3.8 Flash (High). 2026-09-07 사용자 지시로 3.8 전환 + **최고 effort** 고정.
    #   agy(Antigravity CLI)는 reasoning을 모델명에 내장한다(Low/Medium/High) — 별도 플래그 없음.
    #   3.8 Flash는 agy 1.1.27+ 에만 존재(1.1.20에는 3.7까지). MAD_AGY_MODEL로 override.
    # ⚠ `-p`(print) 모드는 **기본 타임아웃 5분**이다(`--print-timeout`, 실측 2026-09-08).
    #   무거운 감사(파일 다수 열람 + 테스트 재현)는 5분을 넘겨 **로그도 산출도 없이 조용히 죽는다**.
    #   두 번 연속 그렇게 잃었다 — PING은 정상이라 stall/usage-limit로 오진하기 쉽다.
    #   MAD_DISPATCH_TIMEOUT(watchdog)과 별개이므로 반드시 함께 늘린다.
    agytimeout="${MAD_AGY_PRINT_TIMEOUT:-${MAD_DISPATCH_TIMEOUT:-1800}s}"
    [[ "$agytimeout" =~ ^[0-9]+$ ]] && agytimeout="${agytimeout}s"
    cmd=(agy --add-dir "$proj" --model "${MAD_AGY_MODEL:-Gemini 3.8 Flash (High)}" \
         --print-timeout "$agytimeout" -p "$full" --dangerously-skip-permissions)
    ;;
  codex)
    # **CLI 직접 호출이 기본 방침(2026-09-07 사용자 지시).** MCP 서버 경로는 쓰지 않는다.
    #   근거: (a) `codex exec --json`이 턴마다 usage를 뱉어 **토큰 사용량을 정밀 관측**할 수 있다
    #         (MCP 도구 결과에는 usage가 없다) — Plus 요금제 할당량 관리에 이게 결정적이다.
    #     (b) `codex exec resume --last`로 **세션을 이어갈 수 있다** — MCP의 codex-reply와 동등.
    #         "CLI는 매번 새 세션"은 사실이 아니다.
    #     (c) 백그라운드 실행·폴링·타임아웃을 오케스트레이터가 직접 제어한다(MCP는 반환까지 블록).
    #   MCP 서버(`codex mcp-server`)는 codex 0.154.0에서 **제거**됐다(2026-09-15). 위 세 이유로 원래도 미사용.
    #
    # 다운스트림 MCP 서버(vercel/figma/copilot 등) 인증 hang 회피를 위해 MCP 없는 임시
    #   CODEX_HOME으로 구동한다(2026-06-28 진단 유지).
    # 모델: gpt-6-astra. **CLI 0.153.4+ 필요** — 구 버전은 "requires a newer version of Codex" 400.
    # reasoning: **기본 effort 사용**(사용자 지시) — model_reasoning_effort를 주입하지 않는다.
    #   CODEX_HOME의 config.toml에도 effort를 고정하지 말 것. override는 MAD_CODEX_EFFORT로만.
    nh="${MAD_CODEX_HOME:-$HOME/.codex-nomcp}"
    mkdir -p "$nh"
    [[ -f "$nh/auth.json" ]] || { [[ -f "$HOME/.codex/auth.json" ]] && cp -f "$HOME/.codex/auth.json" "$nh/auth.json"; }
    [[ -f "$nh/config.toml" ]] || printf 'model = "gpt-6-astra"\n' > "$nh/config.toml"
    cxargs=(--skip-git-repo-check --json -m "${MAD_CODEX_MODEL:-gpt-6-astra}"
            --sandbox danger-full-access -c approval_policy=never)
    [[ -n "${MAD_CODEX_EFFORT:-}" ]] && cxargs+=(-c "model_reasoning_effort=${MAD_CODEX_EFFORT}")
    # --json: JSONL 이벤트. turn.completed 에 usage(input/cached_input/output/reasoning_output)가 실린다.
    #   mad-usage.sh 로 집계 가능. 산출 파일은 에이전트가 직접 쓰고 stdout은 폴백.
    cmd=(env CODEX_HOME="$nh" codex exec "${cxargs[@]}" "$full")
    ;;
  deepseek)
    # DeepSeek V4 Pro: 에이전틱 CLI 없음(2026-09-07 재확인 — deepseek/ds 실행파일 부재, Responses API
    #   미지원이라 codex 경로 불가). deepseek_agent.py(chat completions + function calling 미니
    #   에이전트)가 read/list/write/run 도구 루프를 제공한다. 키는 ~/.deepseek/api_key 또는 $DEEPSEEK_API_KEY.
    # 모델: **deepseek-flash** (= DeepSeek-V4.1-Flash). 2026-09-22 A/B 실측으로 v4-pro에서 전환:
    #   품질 동률(격리 4회 평균 9.4 vs 9.6, 모델 내 분산 ~1.4가 모델 간 차 0.2를 압도)인데
    #   pro는 900초 기본 설정에서 **0/3 완주**(flash 3/3), 1회 15~40분 vs 3~8분, 가격 3~4배.
    #   더 어려운 결함은 codex 등 최상위가 잡는다는 판단(사용자 지시 2026-09-22).
    #   ⚠ pro로 되돌리려면 DEEPSEEK_MODEL=deepseek-v4-pro + MAD_DISPATCH_TIMEOUT>=2400 필수.
    # 2026-09-22 실측 API 목록은 **둘뿐**:
    #   deepseek-flash (= DeepSeek-V4.1-Flash, 신형) / deepseek-v4-pro (별도 유지).
    #   ★구 별칭 deepseek-v4-flash·deepseek-v4-flash-vision-exp·deepseek-chat·deepseek-reasoner는
    #     전부 deepseek-flash로 라우팅된다(응답 model 필드가 요청과 다른 이름을 돌려주는 것이 근거).
    #     `deepseek-v4.1-flash`라는 id는 API가 거부한다 — 그 이름을 쓰지 말 것.
    #   pro는 flash 대비 입력 4.4배·출력 3.3배 비싸고 비전 미지원. 교체 시 DEEPSEEK_MODEL로 override.
    # reasoning: API enum = none/minimal/low/medium/high/xhigh/max (실측). 사용자 지시가
    #   "최대에서 한 단계 아래"이므로 **xhigh** 고정. MAD_DEEPSEEK_EFFORT로 override.
    export AGENT_REASONING_EFFORT="${MAD_DEEPSEEK_EFFORT:-xhigh}"
    cmd=(python3 "$SCRIPT_DIR/deepseek_agent.py" --cwd "$proj" --prompt-file "$promptfile" \
      --max-turns "${MAD_DEEPSEEK_TURNS:-40}")
    ;;
  grok)
    # 2026-10-06 사용자 지시로 재합류: "multi-ai-debate에 grok을 포함시키자. 없는 때가 있다면 제외하고 진행".
    #   모델·effort = "가장 최근 모델과 가장 높은 effort": grok-4.7(`grok models` 기본·최신) + xhigh
    #   (CLI 허용값 xhigh/high/medium/low — `max`는 "unknown effort level"로 거절). MAD_GROK_MODEL·MAD_GROK_EFFORT로 override.
    # 전송 = CLI 직접 호출. ⚠ Claude MCP `mcp__grok__grok` 브리지는 세션 시작 때 띄운 구 CLI(1.0.5)를 물고 있어
    #   426 "CLI version outdated"로 거절된다(2026-10-06 실측, 설치본은 1.0.46) — 쓰지 않는다.
    # ⚠ 격리: grok 헤드리스는 --permission-mode plan·dontAsk에서도 셸 실행·파일 쓰기를 한다(2026-10-06 실측).
    #   과거 유령 커밋 이력도 있다. 그래서 **프로젝트의 일회용 APFS 복제본(.git 비활성)을 cwd로** 돌린다.
    #   산출은 복제본 안의 같은 상대 경로에 쓰게 두고, 끝나면 그 파일을 실제 세션으로 옮긴다(아래 루프).
    command -v grok >/dev/null 2>&1 || mad_die "grok CLI not found (~/.grok/bin/grok)"
    grokclone="$(mktemp -d -t mad-grok.XXXXXX)/proj"
    cp -cR "$proj" "$grokclone" 2>/dev/null || cp -R "$proj" "$grokclone"
    [[ -L "$grokclone" ]] && mad_die "grok clone is a symlink — refusing"
    [[ -e "$grokclone/.git" ]] && mv "$grokclone/.git" "$grokclone/.git.disabled"
    cmd=(grok -m "${MAD_GROK_MODEL:-grok-4.7}" --reasoning-effort "${MAD_GROK_EFFORT:-xhigh}" \
         --cwd "$grokclone" --permission-mode bypassPermissions --prompt-file "$promptfile")
    ;;
  *) mad_die "unknown ai: $ai (use agy|codex|deepseek|grok)";;
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
  # grok은 일회용 복제본 안에 산출을 쓴다 — 실제 세션으로 옮긴다(아래 stdout 폴백보다 먼저).
  if [[ "$ai" == "grok" && -z "$killed" && "$rc" -eq 0 && -s "$grokclone/$sess_rel/$out" ]]; then
    cp "$grokclone/$sess_rel/$out" "$outfile"
  fi
  # 전 참여자가 CLI/API 직접 호출이다. 에이전트가 산출 파일을
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
