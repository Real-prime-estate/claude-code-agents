---
name: multi-ai-debate
description: Claude(오케스트레이터)가 codex(GPT-5.5)와 agy(Gemini)를 Bash로 직접 구동해 파일 기반으로 토론·구현·검증하고, 오케스트레이터 할루시네이션을 막는 게이트(Claim Ledger / spec-review / synthesis 비준 / red-team)를 강제하는 멀티-AI 협업 시스템
metadata:
  priority: 8
  promptSignals:
    phrases:
      - "multi-ai"
      - "multi ai"
      - "멀티 ai"
      - "세 AI"
      - "codex와 gemini"
      - "토론시켜"
      - "오케스트레이터"
      - "교차검증"
    anyOf:
      - "codex"
      - "gemini"
      - "agy"
      - "비준"
      - "검증"
      - "구현"
    noneOf:
      - "think-deep"
    minScore: 5
---

# Multi-AI Debate — 오케스트레이션 + 감사 게이트

Claude(나)가 **오케스트레이터**로서 두 외부 CLI를 Bash로 직접 구동해 파일 기반 협업을 진행한다.
판단(내용 작성)은 LLM 3자가, 결정론적 배관(세션·디스패치·게이트)은 `scripts/`가 맡는다.

## 역할 / 모델 / 권한 (항상 우회 ON)

| 역할 | CLI | 모델 | 권한 우회 플래그 |
|------|-----|------|------------------|
| 오케스트레이터 | (이 세션) | Claude | — (내용은 Write 툴로 직접) |
| 참여/구현 | `codex` | GPT-5.5 Thinking (`gpt-5.5`, reasoning=high) | `--dangerously-bypass-approvals-and-sandbox` |
| 참여/검증 | `agy` | Gemini 3.5 Flash (High) | `--dangerously-skip-permissions` |

`scripts/mad-dispatch.sh`가 위 플래그와 Audit Packet을 자동 주입한다. 직접 명령을 쓸 때는:
- `codex exec --cd <PROJ> --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox -c mcp_servers='{}' "<프롬프트>"`
- `agy --add-dir <PROJ> -p "<프롬프트>" --dangerously-skip-permissions`

## 전제 점검 (첫 실행 시)

```sh
command -v codex && codex login status        # ChatGPT 로그인 확인
command -v agy   && agy -p "PONG" --dangerously-skip-permissions   # 응답 확인
```
없거나 미인증이면 사용자에게 알리고 진행 방식을 조정한다. (`agy`가 없으면 `~/.local/bin` 확인.)

## 프로토콜 (단계)

`topic → position → critique → [spec-review (Gate 1)] → synthesis → ratify (Gate 2) → decision`

- 파일: 세션 디렉토리에 `NN-<phase>-<author>.md`. phase ∈ {topic, position, critique, spec, spec-review, synthesis, ratify, decision, audit}.
- 각 AI는 **독립적으로** position을 쓰고(상대 글 안 봄), critique부터 서로의 원문을 읽는다.
- 라운드 내 2개 외부 AI는 **병렬**(Bash run_in_background), 라운드 간은 순차. 내 몫(claude)은 Write로 직접.

## 감사 게이트 (오케스트레이터 할루시네이션 방지 — 항상 적용)

핵심 인식: 오케스트레이터 오류는 spec/인수기준·synthesis·decision·검증oracle에서 *영구화*된다. 게이트는 오류를 없애지 못하고 **전파 경로를 끊는다.** 고위험 산출물에만 적용한다.

1. **Claim Ledger** (고위험 산출물 필수): 표 `id|claim|type|evidence|source|check|status`.
   - `type` ∈ {fact, assumption, invariant, metric-contract, decision, open-question}
   - `evidence` ∈ {source, measurement, proof-sketch, counterexample-search, assumption-only, unsupported}
   - **차단규칙**: `invariant`/`metric-contract`가 `unsupported`/`assumption-only`면 pass/fail 금지(관측치로만). → `scripts/mad-ledger-lint.sh <file>`로 검사.
2. **Gate 1 — spec-review** (구현/oracle 작성 *전*): 작성자 외 ≥1 AI가 `go`/`no-go`. → `scripts/mad-gate.sh spec-review`.
3. **Gate 2 — ratify** (synthesis 후, decision *전*; 순서 `synthesis→ratify→decision→PROJECT.md`): `ratify`/`ratify-with-corrections`/`reject`. reject 1건이면 decision 금지. → `scripts/mad-gate.sh ratify`.
4. **Red-Team 5문항** (Gate 1·검증 필수): ①최소 반례? ②이름이 미증명 성질 암시? ③반대결과=실패 vs 신호? ④기준 만족하는 틀린 hack? ⑤GT/미래/offline 정보 누설?
5. **반증형 검증**: "확인"이 아니라 "반증 시도 + 탐색공간(시드/경계) 보고". 수치/불변식은 다중시드(≥5)+스트레스 기본.
6. **Audit Packet**: 외부 AI는 프롬프트만 믿지 말고 원문 직접 조회 + 응답 첫 부분에 read-set 선언(`mad-dispatch.sh`가 강제 주입).
7. **Decision Diff**: decision 파일에 `Decision / Decision Diff / Claim Ledger / PROJECT.md Updates / Not Reviewed / Implementation Gate`.

## 스크립트 사용법

작업 디렉토리는 `PROJECT.md`가 있는 프로젝트 안. (스크립트가 상위로 `PROJECT.md`를 탐색; `MAD_PROJECT_DIR`로 override.)

```sh
SK=~/.claude/skills/multi-ai-debate/scripts

# 1) 새 세션 + topic 스켈레톤
"$SK/mad-new.sh" "B2 정의를 어떻게 할 것인가"

# 2) 외부 AI 디스패치 (프롬프트는 파일로 전달; 백그라운드 권장)
#    내용은 prompt 파일에, 산출 파일명/AI/추가 read-set만 인자로.
printf '%s' "당신 입장을 ... 작성하라" > /tmp/p.txt
"$SK/mad-dispatch.sh" codex 01-position-codex.md /tmp/p.txt
"$SK/mad-dispatch.sh" agy   02-position-agy.md   /tmp/p.txt
#    → Bash 툴에서 run_in_background=true 로 두 개를 동시에 띄우고 mad-status로 폴링.
#    MAD_DRY_RUN=1 로 명령만 미리보기 가능.

# 3) 진행 상황 폴링 (알림에 의존하지 말 것 — CLI 직접 구동이라 누락될 수 있음)
"$SK/mad-status.sh"

# 4) 게이트 검사
"$SK/mad-gate.sh" spec-review   # Gate 1
"$SK/mad-gate.sh" ratify        # Gate 2

# 5) Claim Ledger 린트
"$SK/mad-ledger-lint.sh" discussion/<세션>/07-synthesis-claude.md
```

## 오케스트레이터 행동 규칙 (자기 규율)

- **자기보고 불신**: 외부 AI(또는 내) "통과했다"를 재현 없이 신뢰하지 말 것. 핵심 수치/검사는 내가 직접 실행해 raw 출력으로 확인.
- **요약 비신뢰**: synthesis는 원문 파일을 직접 인용하고 출처 앵커를 단다. 비준(Gate 2)으로 왜곡을 차단.
- **불변식 금지**: 증명/조건/반례탐색 없는 명제를 인수기준 pass/fail로 부과하지 말 것(`mad-ledger-lint`로 자기검사).
- **폴링**: 외부 CLI는 분 단위. `run_in_background`로 띄우고 `mad-status.sh`로 확인. 종료 알림이 안 올 수 있음.
- **codex stall 주의**: codex의 설정된 MCP 서버 인증이 간헐적으로 hang되어 작업이 멈춘다(증상: 프로세스 etime↑인데 CPU≈0, 출력에 `rmcp ... AuthRequired`). `mad-dispatch.sh`가 MCP 없는 `~/.codex-nomcp`(CODEX_HOME)로 구동해 이를 차단한다. 그래도 etime↑·CPU≈0가 5분 이상이면 `pkill -f 'codex exec'` 후 재디스패치.
- **결정론은 스크립트로**: 세션 생성·디스패치·게이트는 손으로 하지 말고 스크립트로(누락 방지).

## think-deep 와의 차이

`think-deep`은 Claude 서브에이전트 3개의 내부 토론이다. 이 skill은 **서로 다른 벤더의 외부 CLI(codex/agy)를 실제로 구동**해 교차검증하고, 오케스트레이터 자신을 감사하는 게이트를 강제한다.
