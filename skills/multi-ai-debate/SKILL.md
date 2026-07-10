---
name: multi-ai-debate
description: Claude(오케스트레이터)가 codex(GPT-5.5)·agy(Gemini)·grok(xAI)·deepseek(V4 Pro) 4종을 Bash로 직접 구동해 파일 기반으로 토론·구현·검증하고, 오케스트레이터 할루시네이션을 막는 게이트(Claim Ledger / spec-review / synthesis 비준 / red-team)를 강제하는 멀티-AI 협업 시스템
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
      - "grok"
      - "비준"
      - "검증"
      - "구현"
    noneOf:
      - "think-deep"
    minScore: 5
---

# Multi-AI Debate — 오케스트레이션 + 감사 게이트

Claude(나)가 **오케스트레이터**로서 **네 외부 AI(codex·agy·grok·deepseek)를 항상** Bash로 직접 구동해 파일 기반 협업을 진행한다.
판단(내용 작성)은 LLM 5자가, 결정론적 배관(세션·디스패치·게이트)은 `scripts/`가 맡는다.

**기본 규칙: 외부 AI는 codex·agy·grok·deepseek 4종을 모두 쓴다.** 임의로 어느 하나를 빼지 않는다. deepseek는 대타가 아니라 **상시 기본 멤버**다.

> **glm(GLM-5.2) 로스터 제외(2026-07-08 사용자 지시)**: z.ai API 사용량 소진 + 비용 과다로 상시 로스터에서 뺐다.
> `mad-dispatch.sh`의 glm 배관은 남아 있으나 **사용자가 명시 재지시할 때만** 재합류(그때 키·예산부터 확인).

> ### 🚫 정족수 = 하드 차단 게이트 (position·critique·spec-review·ratify·해석검증 라운드 필수)
> **외부 AI 산출이 3개 미만이면 그 라운드의 synthesis/verdict/결론을 쓰지 말 것.** 이건 "가능하면"이 아니라 **차단**이다.
> 하나라도 빠지면 반드시 아래 순서로 복구한 *뒤에만* 종합한다:
> 1. **빠진 AI의 실패를 PING으로 분류**(아래 "실패 진단 프로토콜"). 빈 출력·exit 1·exit 143(kill)·timeout·stall을 **절대 "transient"로 추정 금지** — PING 증거 없이 원인을 부르지 않는다. **codex가 stall처럼 보이면 반드시 원인부터 파악한다.**
> 2. **usage limit 확정이면 그 AI만 제외하고 나머지로 진행**(예: codex limit → agy·grok·deepseek 3자). 회복 시각이 세션 내면 CronCreate로 복귀 병행.
> 3. **stall/인증오류면** kill 후 1회 재디스패치. 그래도 실패면 제외하고 나머지로 진행.
> 4. **3개를 못 채우는 게 확정된 경우에만** 사용자에게 "N/4로 진행 여부"를 명시적으로 물어 승인받고, 그 사실을 산출 파일 종합 헤더에 **"⚠ 정족수 미달 N/4 (사유)"**로 남긴다.
>
> **금지 패턴(2026-07-06 실측 실패)**: codex가 빈 exit 1(usage-limit 위장)로 죽자 PING 없이 "transient stall"로 오판→일부만으로 그냥 종합. → PING했으면 usage limit이 즉시 드러나 제외 처리하고 나머지 전원으로 진행했을 것. **어떤 라운드든 "N/4, 나머지는 대충 넘어감"으로 끝내지 말 것.**

## 역할 / 모델 / 연결 (항상 권한우회 ON)

| 역할 | 에이전트 | 모델 | 연결(transport) |
|------|-----|------|------------------|
| 오케스트레이터 | (이 세션) | Claude | — (내용은 Write 툴로 직접) |
| 참여/구현 | `codex` | **GPT-5.6 Sol** (`gpt-5.6-sol`, reasoning=**high**; 2026-07-10 전환 — CLI 0.144.1+ 필요) | **MCP** — `codex mcp-server`(네이티브 stdio) |
| 참여/검증 | `agy` | **Gemini 3.5 Flash (High)** (2026-07-06 A/B로 전환 — 3.1 Pro (High)의 간헐 6분+ 지연 회피, 실전 감사 정확도 동등 확인. reasoning은 모델명 내 Low/Medium/High로 내장, 별도 thinking 플래그 없음. 3.5 Pro 출시 시 재평가) | CLI — `agy --model … -p` (MCP/ACP 서버모드 없음) |
| 참여/검증 | `grok` | Grok (xAI) Build, reasoning=**xhigh** | **ACP→MCP** — `grok agent stdio`를 `grok_acp_mcp_bridge.py`가 MCP로 래핑 |
| 참여/검증(대용량 감사) | `deepseek` | **DeepSeek V4 Pro** (1M ctx, API 종량 ~$0.2/토론) | CLI — `deepseek_agent.py`(chat+function calling 미니 에이전트; Responses API 미지원이라 codex 경로 불가, 2026-07-05). 키 `~/.deepseek/api_key` |
| ~~제외~~ | `glm` | ~~GLM-5.2~~ **2026-07-08 로스터 제외**(z.ai API 소진·비용) | (배관은 잔존: `deepseek_agent.py` env 주입·`MAD_GLM_THINKING=disabled` 기본. 재합류=사용자 명시 지시 시만) |

**reasoning(생각 수치)**: codex(gpt-5.6)의 effort enum은 **none/minimal/low/medium/high/xhigh**(2026-07-10 실측 — 구판의 max 폐지, **xhigh가 최상단**). 기본은 최상단보다 한 단계 아래 **high**(2026-07-10 사용자 지시; codex `model_reasoning_effort`, MAD_CODEX_EFFORT로 override). grok은 **xhigh** 유지(`--effort`, GROK_EFFORT로 override). agy는 모델명 내장 **High**(3.5 Flash 기준; 별도 플래그 없음).

**연결 모델(2026-07-03 개편)**: codex/grok는 **MCP stdio 서버**로 구동하고 `scripts/mcp_call.py`(1회성 MCP 클라이언트)로 툴을 호출한다. 둘 다 에이전틱 세션(cwd 루트의 read/write/shell 도구 보유)이라 Audit Packet 지시대로 **산출 파일을 스스로 쓴다**(stdout은 폴백). agy만 여전히 CLI.

- codex: `codex mcp-server` → 툴 `codex`/`codex-reply`. 다운스트림 MCP 서버 stall 회피를 위해 `CODEX_HOME=~/.codex-nomcp`로 구동. `sandbox=danger-full-access`+`approval-policy=never`로 권한우회.
- grok: 네이티브 MCP 없음 → `grok_acp_mcp_bridge.py`가 ACP(`grok agent stdio`)를 MCP로 브릿지. 툴 `grok`/`grok_reply`(세션형). permission 요청 자동승인(=bypassPermissions). 인증은 `~/.grok/auth.json`(cached_token).
- `scripts/mad-dispatch.sh <agy|codex|grok|deepseek> …`가 위 전송 + Audit Packet을 자동 주입(권장 경로). deepseek는 미니 에이전트 브릿지(`deepseek_agent.py`; glm도 같은 브릿지였으나 로스터 제외).
- **직접(대화형)**: codex/grok는 Claude에 MCP 서버로 등록됨(`claude mcp add -s user`) → 세션 재시작 후 `mcp__codex__codex` / `mcp__grok__grok`(+`_reply`) 툴로 직접 호출 가능. 단 긴 감사는 mad-dispatch 백그라운드 경로가 낫다(MCP 툴 호출은 반환까지 블록).

## 전제 점검 (첫 실행 시)

```sh
# codex/grok MCP 서버 연결 상태 (등록돼 있으면 mcp list로 확인)
claude mcp list 2>/dev/null | grep -iE "codex|grok"   # 둘 다 ✔ Connected 기대
command -v agy && agy --model "Gemini 3.5 Flash (High)" -p "PONG" --dangerously-skip-permissions   # agy 응답 확인
# 미등록 시: claude mcp add -s user codex -e CODEX_HOME=~/.codex-nomcp -- codex mcp-server
#            claude mcp add -s user grok -- python3 ~/.claude/skills/multi-ai-debate/scripts/grok_acp_mcp_bridge.py
```
셋 다 확인한다. 없거나 미인증이면 사용자에게 알리고 진행 방식을 조정한다. (`agy`가 없으면 `~/.local/bin`, `grok`이 없으면 `~/.grok/bin`; grok 인증은 `grok` 1회 로그인으로 `~/.grok/auth.json` 생성.)

## 프로토콜 (단계)

`topic → position → critique → [spec-review (Gate 1)] → synthesis → ratify (Gate 2) → decision`

- 파일: 세션 디렉토리에 `NN-<phase>-<author>.md`. phase ∈ {topic, position, critique, spec, spec-review, synthesis, ratify, decision, audit}.
- 각 AI는 **독립적으로** position을 쓰고(상대 글 안 봄), critique부터 서로의 원문을 읽는다.
- **최소 2회 토론 라운드 권장 — 1왕복 확증 금지**: position→critique 1왕복만으로 synthesis에 가지 말 것. critique에서 나온 반론·교정을 반영한 **수정 position(또는 반박·재검증) 라운드를 최소 1회 더** 거친 뒤 종합한다. 한 번의 라운드는 첫 인상에 대한 상호 확증으로 수렴하기 쉽다 — 반론이 소화된 뒤에도 살아남는 주장만 decision에 올린다. 예외: 단순 수치 재현 확인 같은 경량 검증은 1라운드 가능하되, decision에 **라운드 수와 그 사유를 명기**한다. (실측 근거: 압축 연구 세션들에서 2~3라운드째에 결론을 뒤집는 교정이 반복 발견됨 — 이종 짝 비교, LOO leakage, k=4 전 조합 우위 반례 전부 후속 라운드 산출.)
- 라운드 내 **4개 외부 AI(codex·agy·grok·deepseek)는 병렬**(Bash run_in_background), 라운드 간은 순차.
> ### 🗣️ claude(오케스트레이터)는 매 판단 라운드의 **필수 참여 멤버** — 종합만 하지 말 것 (하드 규칙)
> **claude는 오케스트레이터인 *동시에* 정식 토론자다. 모든 판단 라운드(position·critique·rebuttal·verify·interp)에서
> 외부 AI를 디스패치하는 것과 *별개로* 자기 산출 `NN-<phase>-claude.md`를 Write로 직접 낸다. 이건 "권장"이 아니라 차단 규칙.**
> - **디스패치=참여 아님**: 외부 3~4자만 띄우고 claude 몫을 빼먹은 채 synthesis로 가는 것은 **프로토콜 위반**. 각 판단
>   라운드 종료 조건 = {외부 산출 정족수} **∧** {claude 산출 존재}. claude 파일 없이 그 라운드를 닫지 말 것.
> - **독자적 실질 분석 의무**: claude 산출은 남의 요약·중계가 아니라 **자기만의 입장·반례·측정·자기수정**을 담는다(2026-07
>   실증: claude가 IDW 해법·정수화·range coder 실측, 재프레이밍·순환-레버 반박, provenance 자기정정을 냈고, 그 오류는
>   외부 멤버가 적발 — 참여와 견제가 양립함). "외부가 다 말했으니 claude는 생략"은 금지 — 살아남을 논점이든 자기수정이든 반드시 기여.
> - **자기 규율 2**(불변): ① synthesis에서 claude 산출을 **우대 금지**(다른 멤버와 동일 비중 인용·대조, "5자 수렴"에
>   claude 포함 여부 정확히). ② **claude 산출·synthesis·decision·spec도 ratify/Gate1 감사의 *명시* 대상**(외부 멤버 프롬프트에
>   "오케스트레이터 오류·자기우대·낙관 적발"을 과제로 박아 넣는다). claude의 낙관·provenance 결함 이력은 외부 교차검증의 *주* 표적이다.
> - **claude가 유일 실행자**: 코드 직접 재현·raw 파싱·게이트 실행은 claude만 함(자기보고 불신). 이 실행 결과도 claude 산출의 근거로 명기.
- **새 세션은 반드시 `mad-new.sh`로 생성(또는 `discussion/.current-session` 갱신 확인) 후 디스패치** — 포인터 미갱신 시 산출이 직전 세션 파일을 덮어쓴다(2026-07-06 유실 사고).

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
8. **코드/재정형 감사 평가 프로파일** (감사 대상이 **코드**일 때 — Red-Team 5문항(항목 4)은 ML/수치 주장용이라 이걸로 대체·보강): 각 결함은 판정 `CONFIRMED(구체 입력→다른 출력/상태 재현 첨부) / PLAUSIBLE / REFUTED`, 정족수 ≥3 외부 AI. 축:
   - **공통 축(3):** ③ **컨벤션 준수(letter)** = 언어 정본 컨벤션(c는 `coding-conventions/c.md` §13) 체크리스트 기계 대조 — 미준수 항목 나열, 주관 배제. ④ **빌드·검증 불변(하드 차단)** = 매트릭스(clang/gcc/MSVC 등)·단위/golden 테스트·sanitizer/validation을 **오케스트레이터가 직접 실행**(self-report 불신), 기준(재정형 전 또는 이전 릴리스) 대비 **동일**해야 통과. ⑤ **관용 보존(spirit)** = 언어 계보 관용(C=KNF/BSD: `sizeof(*p)`·`goto cleanup`·`for (;;)`·소유권 이전 NULL 대입·언어와 안 싸움) 유지, 체크리스트는 통과하나 비관용적인 구조 적발. **주석 문법·분량은 이 축에서 제외**(§7 의도적 하우스 이탈, c-executor 극단 최소화 내장).
   - **재정형 프로파일 (동작 불변 스타일 변경):** 공통 + ① **행위 불변(하드 차단)** = 각 hunk가 순수 스타일(공백·중괄호·`//`·`return()`·선언순서)인가 vs 의미 변경(제어흐름·평가순서·타입·값·부작용 횟수). 결함은 **구체 재현 필수**, "바뀐 듯"은 기각. + ② **계약 손실 없음(차단)** = 주석 최소화가 전제·소유권·오류·불변식(하중지지 계약)을 삭제했나(프로즈 삭제=OK). ①·④ 미증명 시 채택 금지.
   - **신규-로직 프로파일:** 공통(③④⑤) + **정확성**(구체 실패 시나리오)·**경계/UB**(배열·NULL·오버플로·부호변환·초기화, c.md §12)·**동시성**(happens-before·경쟁)·**ABI**(다컴파일러×다OS 정합).

## 스크립트 사용법

작업 디렉토리는 `PROJECT.md`가 있는 프로젝트 안. (스크립트가 상위로 `PROJECT.md`를 탐색; `MAD_PROJECT_DIR`로 override.)

```sh
SK=~/.claude/skills/multi-ai-debate/scripts

# 1) 새 세션 + topic 스켈레톤
"$SK/mad-new.sh" "B2 정의를 어떻게 할 것인가"

# 2) 외부 AI 디스패치 (프롬프트는 파일로 전달; 백그라운드 권장)
#    내용은 prompt 파일에, 산출 파일명/AI/추가 read-set만 인자로.
printf '%s' "당신 입장을 ... 작성하라" > /tmp/p.txt
"$SK/mad-dispatch.sh" codex    01-position-codex.md    /tmp/p.txt
"$SK/mad-dispatch.sh" agy      02-position-agy.md      /tmp/p.txt
"$SK/mad-dispatch.sh" grok     03-position-grok.md     /tmp/p.txt
"$SK/mad-dispatch.sh" deepseek 04-position-deepseek.md /tmp/p.txt
# claude(오케스트레이터) 몫은 디스패치 없이 Write로 직접: 05-position-claude.md
#    → Bash 툴에서 run_in_background=true 로 넷을 동시에 띄우고 mad-status로 폴링.
#    deepseek 무거운 감사는 MAD_DISPATCH_TIMEOUT=600~900 권장(1차 420s 타임아웃 실측).
#    grok은 재실행이 무거울 수 있으니 MAD_DISPATCH_TIMEOUT=900 을 export해 둔다.
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
- **codex stall 주의**: codex `mcp-server`도 다운스트림 MCP 서버 인증이 hang되면 멈춘다(증상: etime↑·CPU≈0). `mad-dispatch.sh`가 `CODEX_HOME=~/.codex-nomcp`로 서버를 띄워 MCP 로딩을 차단한다. 그래도 5분 이상 stall이면 mad-dispatch watchdog가 kill+retry. 수동 개입 시 `pkill -f 'codex mcp-server'` 후 재디스패치. 무거운 작업은 `MAD_DISPATCH_TIMEOUT=900`. **단 "stall처럼 보임 = stall"로 단정 금지 — 아래 "실패 진단 프로토콜"의 PING으로 usage-limit과 구분한 뒤 행동**(빈 exit 1은 usage-limit 위장이 잦다).
- **grok stall 주의**: 브릿지(`grok_acp_mcp_bridge.py`)는 `grok agent stdio` 자식을 직접 띄우고 `mcpServers: []`로 세션을 열어 죽은 MCP 상속 문제를 회피한다. 그래도 hang이면(증상: etime↑·CPU≈0, 자식 `grok agent stdio`) watchdog가 kill+retry; 수동 시 `pkill -f 'grok agent stdio'`. 인증 실패(`ACP authenticate failed`)는 `grok` 1회 로그인으로 `~/.grok/auth.json` 갱신.
- **에이전트 side-effect 금지**: codex/grok는 권한우회(full access) 상태라 워크스페이스 CLAUDE.md의 "커밋·push" 지시를 오독해 자율 커밋/푸시할 수 있다(2026-07-03 실제 발생, force-push로 수습). Audit Packet에 "git 쓰기·소스 수정 금지, 산출 파일만" 규칙을 넣어 차단했다 — 유지할 것. 디스패치 후 `git log`로 유령 커밋 확인 권장.
- **⚠ 실패 진단 프로토콜 — 어떤 비정상 종료든 원인 추정 금지, PING으로 분류 후 행동**: 외부 AI가 산출 파일 없이 죽으면(빈 출력, exit 1, exit 3, exit 143/kill, timeout, stall 무엇이든) **"transient"·"일시적"으로 추정하고 넘어가지 말 것.** 반드시 아래 결정 트리를 실행한다.
  1. **PING**: `CODEX_HOME=~/.codex-nomcp codex exec --skip-git-repo-check "reply with exactly: OK" </dev/null 2>&1 | tail`. (grok은 `mcp__grok__grok` 또는 브릿지 재호출; agy는 `agy … -p PONG`.)
  2. **PING이 usage-limit 신호**("hit your usage limit"·"try again at …"·429·quota)를 뱉으면 → **usage limit 확정**. 재시도 금지(quota만 소모). **그 AI만 제외하고 나머지 멤버 전원으로 진행**(정족수 3 이상 유지 확인). 회복시각이 세션 내(수 시간)면 `CronCreate`로 복귀도 병행.
  3. **PING이 정상 응답(OK)**이면 → 직전 실패는 stall/transient였음이 *증명됨*. 그때만 kill 후 1회 재디스패치.
  4. **PING 자체가 hang**이면 → stall 확정. `pkill -f 'codex mcp-server'` 후 재디스패치 1회, 그래도면 제외하고 나머지로 진행.
  - **핵심**: `mad-dispatch.sh`의 usage-limit 자동감지는 codex가 MCP isError로 **빈 출력 exit 1**로 죽으면 우회된다(2026-07-04·2026-07-06 두 번 실측). 그래서 **exit 코드만 보고 원인을 부르는 것이 반복 실패의 근원** — exit 1이든 143이든 **PING 분류가 유일한 진실 소스**다. PING을 건너뛰면 usage-limit을 stall로 오판해 대타를 안 넣고 2/3으로 종합하게 된다(위 정족수 게이트 위반).
  - 다른 AI 산출물은 이미 있으면 재실행 불필요.
- **결정론은 스크립트로**: 세션 생성·디스패치·게이트는 손으로 하지 말고 스크립트로(누락 방지).

## think-deep 와의 차이

`think-deep`은 Claude 서브에이전트 3개의 내부 토론이다. 이 skill은 **서로 다른 벤더의 외부 AI 4종(codex·agy·grok·deepseek)을 실제로 구동**해 교차검증하고, 오케스트레이터 자신을 감사하는 게이트를 강제한다.
