#!/usr/bin/env bash
# Lint a Claim Ledger markdown table for the safeguard rules (column-accurate).
# Header must contain a `type` column and an `evidence` column.
# Flags (exit 1 if any data row violates):
#   - type 값이 합의 enum 밖 (fact|assumption|invariant|metric-contract|decision|open-question),
#     특히 괄호형(예: invariant(proven)).
#   - type ∈ {invariant, metric-contract} 인데 evidence ∈ {unsupported, assumption-only}
#     → pass/fail acceptance criterion 금지 (Gate 1 No-Go). 관측치로만 허용.
# 검사는 type/evidence "컬럼 값"만 본다 (claim 프로즈의 키워드 오탐 방지).
# Usage: mad-ledger-lint.sh <markdown_file>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

f="${1:?markdown_file}"
[[ -f "$f" ]] || mad_die "file not found: $f"

awk -F'|' '
function trim(s){ gsub(/^[ \t]+|[ \t]+$/,"",s); return s }
function lc(s){ return tolower(s) }
BEGIN{ ti=0; ei=0; bad=0; have_table=0 }
/^[[:space:]]*\|/{
  # split fields; $1 is empty (before leading |)
  # detect header
  is_sep=1
  for(i=2;i<=NF;i++){ c=trim($i); if(c!="" && c !~ /^[:-]+$/){ is_sep=0 } }
  if(is_sep) next

  # header row?
  found_type=0; found_ev=0
  for(i=2;i<=NF;i++){ c=lc(trim($i)); if(c=="type"){found_type=i} if(c=="evidence"){found_ev=i} }
  if(found_type && found_ev){ ti=found_type; ei=found_ev; have_table=1; next }

  if(!have_table) next   # rows before a recognized header are ignored
  type=lc(trim($ti)); ev=lc(trim($ei))
  if(type=="") next

  # Rule A: enum 위반 (괄호형 또는 미허용 토큰)
  if(type !~ /^(fact|assumption|invariant|metric-contract|decision|open-question)$/){
    printf("  enum-violation: type=\"%s\"\n    %s\n", trim($ti), $0); bad=1
  }
  # Rule B: invariant/metric-contract + unsupported/assumption-only
  if((type=="invariant" || type=="metric-contract") && (ev=="unsupported" || ev=="assumption-only")){
    printf("  block-rule: type=%s evidence=%s (pass/fail 금지, 관측치로만)\n    %s\n", type, ev, $0); bad=1
  }
}
END{
  if(!have_table){ print "[ledger-lint] WARN: type/evidence 헤더를 가진 Claim Ledger 표를 찾지 못함: " FILENAME; exit 0 }
  if(bad){ print "[ledger-lint] FAIL: " FILENAME " — Gate 1 No-Go 사유 존재."; exit 1 }
  print "[ledger-lint] OK: " FILENAME
}
' "$f"
