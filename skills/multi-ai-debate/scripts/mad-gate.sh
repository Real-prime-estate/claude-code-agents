#!/usr/bin/env bash
# Enforce the two gates by extracting each reviewer's VERDICT (not prose). Exit non-zero = BLOCKED.
# Usage:
#   mad-gate.sh spec-review   # Gate 1: any reviewer verdict 'no-go' => block implementation
#   mad-gate.sh ratify        # Gate 2: any reviewer verdict 'reject' => block decision
#
# Verdict 추출: 마크다운 장식을 제거한 뒤 한 줄이 정확히 verdict 토큰이거나
#   'Verdict:'/'판정:' 라벨 뒤 토큰인 경우만 인정 (claim 프로즈 오탐 방지).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

gate="${1:?gate (spec-review|ratify)}"
sess="$(mad_session_path)"

case "$gate" in
  spec-review) pat="*spec-review*.md"; block='no-go';  label="Gate 1 (spec-review)"; need="구현/test-oracle 작성";;
  ratify)      pat="*ratify*.md";      block='reject'; label="Gate 2 (ratify)";      need="decision 작성";;
  *) mad_die "unknown gate: $gate";;
esac

extract_verdict() {
  awk '
  function clean(s){ gsub(/[#>*_`]/,"",s); gsub(/^[ \t]+|[ \t]+$/,"",s); return tolower(s) }
  # verdict 토큰이 라인 맨 앞이고 뒤가 영문자/하이픈이 아닌 경우(공백·콜론·마침표·한글 조사·줄끝) 인식.
  # 긴 토큰을 먼저 검사(ratify-with-corrections 가 ratify 로 오인되지 않도록).
  # [2026-09-30 수정] 예전엔 "마지막 일치 줄"이 판정이었다 — 첫 줄 `VERDICT: reject` 뒤 본문에
  #   "ratify-with-corrections를 줄 수 없는 이유" 같은 줄이 오면 reject가 덮여 게이트가 잘못 PASS했다.
  #   또 종결자 집합 [ \t:-] 때문에 "`ratify-with-corrections`." 가 ratify 로 오분류됐다(24-ratify 실측).
  #   이제 'VERDICT:'/'판정:' 라벨 줄의 첫 일치를 우선하고, 라벨 줄이 없을 때만 첫 단독 토큰 줄을 쓴다.
  function tok(c){
    if(c ~ /^ratify-with-corrections([^a-z-]|$)/) return "ratify-with-corrections"
    if(c ~ /^go-with-corrections([^a-z-]|$)/) return "go-with-corrections"
    if(c ~ /^no-go([^a-z-]|$)/) return "no-go"
    if(c ~ /^ratify([^a-z-]|$)/) return "ratify"
    if(c ~ /^reject([^a-z-]|$)/) return "reject"
    if(c ~ /^go([^a-z-]|$)/) return "go"
    return "" }
  { c=clean($0); labeled=(c ~ /^(verdict|판정)[ \t]*:/); sub(/^(verdict|판정)[ \t:]*/,"",c)
    t=tok(c)
    if(t!=""){ if(labeled && lv=="") lv=t; if(fv=="") fv=t } }
  END{ print (lv!="" ? lv : fv) }' "$1"
}

shopt -s nullglob
all=( "$sess"/$pat )
if (( ${#all[@]} == 0 )); then
  echo "[$label] BLOCKED: 해당 단계 파일 없음 ($pat) → $need 금지." >&2
  exit 2
fi

# 개정(rev) 처리: author별로 NN(2자리 일련번호)이 가장 큰 최신 파일만 채택.
# 파일명 규칙 NN-<phase>-<author>.md → author=마지막 '-' 뒤, NN=첫 '-' 앞.
# (bash 3.2 호환을 위해 연관배열 대신 awk 사용.)
files=()
while IFS= read -r p; do
  [[ -n "$p" ]] && files+=( "$p" )
done < <(
  for f in "${all[@]}"; do
    base="$(basename "$f" .md)"; nn="${base%%-*}"; author="${base##*-}"
    printf '%s\t%s\t%s\n' "$author" "$nn" "$f"
  done | awk -F'\t' '{ if($2+0 >= max[$1]+0){ max[$1]=$2; path[$1]=$3 } } END{ for(k in path) print path[k] }'
)

echo "[$label] author별 최신 파일 ${#files[@]}개 (superseded 제외)"
blocked=0
for f in "${files[@]}"; do
  v="$(extract_verdict "$f")"
  if [[ -z "$v" ]]; then
    echo "  - $(basename "$f"): ⚠️ verdict 미검출 → 안전상 BLOCK"
    blocked=1
  elif [[ "$v" == "$block" ]]; then
    echo "  - $(basename "$f"): ❌ verdict=$v"
    blocked=1
  else
    echo "  - $(basename "$f"): ✅ verdict=$v"
  fi
done

if (( blocked )); then
  echo "[$label] BLOCKED: $block(또는 미검출) 존재 → $need 금지. 보완 라운드로 회귀." >&2
  exit 1
fi
echo "[$label] PASS: $need 허용."
