#!/usr/bin/env bash
# Dispatch a phase to an external AI (agy=Gemini / codex=GPT-5.5), with bypass flags
# and a standard Audit Packet prefix injected. The AI writes its output file itself.
#
# Usage:
#   mad-dispatch.sh <agy|codex> <out_relpath> <prompt_file> [read_set_csv]
#     out_relpath : file the AI must write, relative to the current session dir
#                   (e.g. 03-position-codex.md)
#     prompt_file : path to a file containing the task body (avoids shell-escaping)
#     read_set_csv: optional extra files (comma-sep, relative to PROJECT_DIR) to force-read
#
# Env:
#   MAD_DRY_RUN=1   print the command instead of executing
#
# Recommended: invoke this via the Bash tool with run_in_background=true and poll with mad-status.sh,
# since external AIs take minutes.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

ai="${1:?ai (agy|codex)}"
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

case "$ai" in
  agy)
    exec agy --add-dir "$proj" -p "$full" --dangerously-skip-permissions
    ;;
  codex)
    # codex의 설정된 MCP 서버(vercel/githubcopilot/figma 등) 인증 시도가 간헐적으로 hang되어
    # 작업 전체가 stall되는 문제가 있다. `-c mcp_servers={}`는 sub-table 병합으로 완전히 끄지 못한다.
    # → MCP 없는 임시 CODEX_HOME(인증만 복사)으로 구동해 MCP 로딩 자체를 차단한다.
    nh="${MAD_CODEX_HOME:-$HOME/.codex-nomcp}"
    mkdir -p "$nh"
    # 인증 부트스트랩: nomcp auth가 없을 때만 ~/.codex에서 1회 복사.
    # (cp -f로 매번 덮어쓰면 nomcp의 fresh 로그인/회전된 refresh token을
    #  stale ~/.codex로 클로버 → "refresh token already used" 발생. 2026-06-12 수정.)
    [[ -f "$nh/auth.json" ]] || { [[ -f "$HOME/.codex/auth.json" ]] && cp -f "$HOME/.codex/auth.json" "$nh/auth.json"; }
    [[ -f "$nh/config.toml" ]] || printf 'model = "gpt-5.5"\nmodel_reasoning_effort = "high"\n' > "$nh/config.toml"
    exec env CODEX_HOME="$nh" codex exec --cd "$proj" --skip-git-repo-check \
      --dangerously-bypass-approvals-and-sandbox "$full"
    ;;
  *) mad_die "unknown ai: $ai (use agy|codex)";;
esac
