---
name: multi-ai-debate
description: Claude(오케스트레이터)가 외부 AI 4종 codex(GPT-6 Astra)·agy(Gemini 3.8 Flash)·deepseek(V4.1 Flash)·grok(Grok 4.7)을 Bash로 직접 구동하고 Claude Fable 독립 세션과 함께 파일 기반으로 토론·구현·검증하며, 오케스트레이터 할루시네이션을 막는 게이트(Claim Ledger / spec-review / synthesis 비준 / red-team)를 강제하는 멀티-AI 협업 시스템
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
      - "deepseek"
      - "비준"
      - "검증"
      - "구현"
    noneOf:
      - "think-deep"
    minScore: 5
---

# Multi-AI Debate — 오케스트레이션 + 감사 게이트

Claude(나)가 **오케스트레이터**로서 **외부 AI 4종(codex·agy·deepseek·grok)** 을 Bash로 직접 구동하고,
**Claude 독립 세션 1개(Fable)** 를 Agent tool로 스폰해 파일 기반 협업을 진행한다.
판단(내용 작성)은 참여 5자가, 결정론적 배관(세션·디스패치·게이트)은 `scripts/`가 맡는다.

**기본 규칙: 참여자는 codex·agy·deepseek·grok + claude-fable 5자를 모두 쓴다.**
임의로 어느 하나를 빼지 않는다. deepseek·grok은 대타가 아니라 **상시 기본 멤버**다.

> **로스터 변경 이력**
> - **grok 재합류 + 불가 시 제외 — 영구 규칙(2026-10-06 사용자 지시)**: 지시 원문 "multi-ai-debate에 grok을 포함시키자.
>   없는 때가 있다면 제외하고 진행하도록 해." + "그록은 가장 최근 모델과 가장 높은 effort로 사용해."
>   모델 **`grok-4.7`**(`grok models` 기본·최신) · effort **`xhigh`**(CLI 최상단 — `max`는 거절). 전송 = **CLI 직접 호출을
>   일회용 복제본에서**(`mad-dispatch.sh grok`). PING으로 grok 불가(한도·인증·CLI 오류)가 확인되면 **codex와 같은 규칙으로
>   그 라운드에서 빼고 진행**한다 — 재합류 예약·재질문·라운드 재개 없음, 종합 헤더에 "grok 제외(사유)" 한 줄.
>   (이력) 2026-09-07 제외 — 그때의 `grok_acp_mcp_bridge.py`·Claude MCP `mcp__grok__grok`는 구 CLI(1.0.5)를 물고 있어
>   426 "CLI version outdated"로 거절된다(2026-10-06 실측) — 쓰지 않는다.
> - **glm(GLM-5.2) 제외(2026-07-08, 2026-09-07 재확인)**: z.ai 사용량 소진·비용 과다. 배관 제거.
> - **claude-opus 제외(2026-09-22 사용자 지시)**: 2026-09-07에 Opus·Fable 2세션으로 늘렸다가 **Fable 1세션으로 환원**.
>   지시 원문 "opus는 종료시켜. codex, deepseek, agy, fable로만 돌려." 재합류는 사용자 명시 지시가 있을 때만.
> - **codex 불가 시 제외 — 영구 규칙(2026-10-03 사용자 지시)**: 지시 원문 "codex 없으면 codex 제외하고 해. 이건 영구적인 설정이야."
>   PING으로 codex의 usage limit(또는 그 밖의 불가)이 확인되면 그 라운드는 **agy·deepseek + claude-fable 3자로 확정**한다.
>   **회복 시각에 맞춘 재합류 예약(CronCreate)을 하지 않는다.** 끝난 라운드를 codex 때문에 다시 열지 않고, codex를 기다리느라
>   다음 단계를 미루지 않으며, 사용자에게 진행 여부를 다시 묻지 않는다. 새 라운드를 시작할 때 PING이 정상이면 평소처럼 넣는다.
>   종합 헤더에 "codex 제외(usage limit — 영구 규칙)" 한 줄을 남긴다.

> ### 🚫 정족수 = 하드 차단 게이트 (position·critique·spec-review·ratify·해석검증 라운드 필수)
> **외부 AI 산출이 2개 미만이면 그 라운드의 synthesis/verdict/결론을 쓰지 말 것.** 이건 "가능하면"이 아니라 **차단**이다.
> (외부 4종 체제(codex·agy·deepseek·grok)에서도 정족수는 **2**다. codex·grok은 불가 시 제외 영구 규칙이라 살아 있는 외부로 2를 채운다. claude 몫(Fable 1세션)은 아래 별도 하드 규칙으로 항상 필수.)
> 하나라도 빠지면 반드시 아래 순서로 복구한 *뒤에만* 종합한다:
> 1. **빠진 AI의 실패를 PING으로 분류**(아래 "실패 진단 프로토콜"). 빈 출력·exit 1·exit 143(kill)·timeout·stall을 **절대 "transient"로 추정 금지** — PING 증거 없이 원인을 부르지 않는다.
> 2. **usage limit 확정이면 그 AI만 제외하고 나머지로 진행**. agy·deepseek은 회복 시각이 세션 내면 CronCreate로 복귀 병행. **codex·grok은 복귀를 예약하지 않고 제외로 확정한다**(위 영구 규칙).
> 3. **stall/인증오류면** kill 후 1회 재디스패치. 그래도 실패면 제외하고 나머지로 진행.
> 4. **2개를 못 채우는 게 확정된 경우에만** 사용자에게 "N/3으로 진행 여부"를 명시적으로 물어 승인받고, 산출 파일 종합 헤더에 **"⚠ 정족수 미달 N/3 (사유)"**로 남긴다.
>
> **금지 패턴(2026-07-06 실측 실패)**: codex가 빈 exit 1(usage-limit 위장)로 죽자 PING 없이 "transient stall"로 오판→일부만으로 그냥 종합. → PING했으면 usage limit이 즉시 드러나 제외 처리하고 나머지 전원으로 진행했을 것.

## 역할 / 모델 / 연결 (항상 권한우회 ON)

| 역할 | 에이전트 | 모델 / reasoning | 연결(transport) |
|------|-----|------|------------------|
| 오케스트레이터 | (이 세션) | Claude | — (세션·디스패치·게이트·synthesis. **판단 산출은 직접 내지 않는다**) |
| 참여/검증 | `claude-fable` | **Fable 5.1**(`claude-fable-5-1`) 독립 새 세션, effort=**max** | Agent tool(`subagent_type=general-purpose`, `model=fable`) |
| 참여/구현 | `codex` | **GPT-6 Astra**(`gpt-6-astra`), reasoning=**기본**(override 안 함) | **CLI** — `codex exec --json` |
| 참여/검증 | `agy` | **Gemini 3.8 Flash (High)** — High가 최상단(Low/Medium/High) | CLI — `agy --model … -p` (**서버 모드 없음**) |
| 참여/검증(대용량 감사) | `deepseek` | **DeepSeek V4.1 Flash**(`deepseek-flash`), `reasoning_effort=`**`xhigh`** | API — `deepseek_agent.py`(**CLI 없음**) |
| 참여/검증 | `grok` | **Grok 4.7**(`grok-4.7`), `--reasoning-effort `**`xhigh`**(최상단) | CLI — `grok -m … -p`, **일회용 복제본 cwd**(헤드리스는 권한 모드와 무관하게 셸·쓰기를 한다 — 2026-10-06 실측) |

**모델·effort 근거(2026-09-07 실측 지시)**
- **astra = 기본 effort**: `model_reasoning_effort`를 주입하지 않는다. `~/.codex-nomcp/config.toml`에도 effort를 고정하지 말 것(고정하면 '기본'이 아니게 된다). 명시 override는 `MAD_CODEX_EFFORT`로만.
- **gemini = 최고 effort**: agy는 reasoning을 **모델명에 내장**한다(Low/Medium/High). 별도 플래그가 아니라 `Gemini 3.8 Flash (High)`가 곧 최고 effort다. **3.8은 agy 1.1.27+ 에만 존재**(1.1.20에는 3.7까지) — `agy update`로 올릴 것.
- **deepseek = max 한 단계 아래**: API enum 실측 = `none|minimal|low|medium|high|xhigh|max` → **`xhigh`**.
- **deepseek 모델 = `deepseek-flash`(V4.1 Flash)**, 2026-09-22 A/B 실측 후 `v4-pro`에서 전환(사용자 지시).
  근거: 동일 프롬프트·동일 대상·격리 세션 4회씩 채점 결과 **품질 동률**(9.4 vs 9.6, 모델 내 분산 ~1.4 > 모델 간 차 0.2)인데
  pro는 **900초 기본 설정에서 0/3 완주**(flash 3/3)·1회 15~40분·가격 3~4배. 더 깊은 결함은 codex 등 최상위가 담당한다는 판단.
  ★반복 실행 A/B는 **세션 디렉토리 격리 필수** — Audit Packet이 "직전 단계 원문 전부"를 읽히므로 같은 dir에 쌓으면 뒤 실행이 앞 답안을 보고 점수가 부풀려진다(실측: 9.4→19.5).
- **claude 세션 = 최대 effort**: Agent tool effort enum의 최상단 `max`.
- **grok = 최신 모델·최고 effort**(2026-10-06 사용자 지시): `grok models`의 최신 = `grok-4.7` · effort 허용값 `xhigh|high|medium|low` → **`xhigh`**. 새 모델이 나오면 `grok models`로 확인해 `MAD_GROK_MODEL` 또는 `mad-dispatch.sh` 기본값을 올린다.

**⚠ DeepSeek 모델 계열(2026-09-22 실측 — 직접 API 호출로 재확인)**
- **API가 받는 id는 둘뿐이다**: `deepseek-flash`(= **DeepSeek-V4.1-Flash**, 신형) · `deepseek-v4-pro`(= DeepSeek-V4-Pro-0813, **별도 유지**).
- **옛 별칭은 전부 flash로 떨어진다**: `deepseek-v4-flash`·`deepseek-v4-flash-vision-exp`·`deepseek-chat`·`deepseek-reasoner` → 응답 `model`이 **`deepseek-flash`**. (그 필드가 요청을 되울리는 게 아니라는 근거이기도 하다.)
- **`deepseek-v4.1-flash`는 존재하지 않는 id다** — 보내면 400. "V4.1 Flash를 쓴다"는 곧 **`deepseek-flash`**를 쓴다는 뜻이다.
- **`deepseek-v4-pro`는 flash로 라우팅되지 않는다.** "v4는 전부 v4.1-flash로 간다"는 flash 라인에만 참이다.
- 가격(1M, 비피크): flash 입력 $0.15·출력 $0.6 / pro 입력 $0.66·출력 $1.98 — **pro가 입력 4.4배·출력 3.3배**. 컨텍스트 1M·최대출력 384K·thinking 모드는 동일, 비전은 flash만 지원.
- 추론은 이제 모델이 아니라 **`reasoning_effort` 파라미터**다. 단 **effort는 상한이지 하한이 아니다** — 쉬운 질문에선 값을 올려도 추론 토큰이 늘지 않는다(실측: minimal 54 vs xhigh 56).

**연결 모델 — CLI 직접 호출이 기본(2026-09-07 방침). MCP 경로는 이 스킬에서 쓰지 않는다.**

`codex`는 과거 자신을 MCP 서버로 노출했지만(`codex mcp-server`), **그 서브커맨드는 codex 0.154.0에서 제거**됐다(2026-09-15 확인 — 현재 `codex mcp`는 **외부** MCP 서버 관리 전용, `app-server`는 Codex 자체 프로토콜이라 대체재 아님). 아래 세 이유로 원래도 CLI 직접 호출을 택했고, 이제는 그것이 유일한 경로다.

1. **사용량 관측** — `codex exec --json`이 턴마다 `turn.completed`에 `usage`를 싣는다:
   `input_tokens` / `cached_input_tokens` / `cache_write_input_tokens` / `output_tokens` / `reasoning_output_tokens`.
   **MCP 도구 결과에는 usage가 없다.** ChatGPT 구독(Plus) 할당량을 관리하려면 이 관측이 필수다.
   집계는 `scripts/mad-usage.sh`.
2. **세션 연속성** — `codex exec resume --last "<프롬프트>"`(+ `fork`, `queue`)로 세션을 이어간다.
   MCP의 `codex-reply`와 동등하다. **"CLI는 매번 새 세션이라 토큰이 더 든다"는 사실이 아니다.**
3. **실행 제어** — 백그라운드 실행·폴링·타임아웃·watchdog을 오케스트레이터가 직접 쥔다.
   MCP 도구 호출은 반환까지 블록되어 긴 감사에 부적합하고, 지연 원인 진단도 어렵다.

> **MCP를 쓸 수 있으면 쓰라는 원칙은 유지한다** — 다른 작업에서 `mcp__codex__*`가 편할 때가 있고,
> 구조화된 도구 결과가 필요한 경우도 있다. 다만 **이 스킬(다중 AI 토론·감사)에서는 관측과 제어가
> 우선이라 CLI를 쓴다.** MCP로 전환할 이유가 생기면 위 3항목이 해소되는지부터 확인할 것.
>
> ⚠ **버전 함정**: Claude 세션에 등록된 `mcp__codex__*`는 **세션 시작 시점의 바이너리를 물고 있다.**
> CLI를 업그레이드해도 그 프로세스는 구 버전이라 `gpt-6-astra`가 400으로 거부된다(2026-09-07 실측).
> "모델이 없다"로 오진하지 말 것.

- agy·gemini CLI의 `mcp` 서브커맨드는 *자신이 소비할* 서버 관리용이지 노출이 아니다(2026-09-07 확인).
- codex는 다운스트림 MCP 서버(vercel/figma/copilot) 인증 hang 회피를 위해 `CODEX_HOME=~/.codex-nomcp`로 구동.
  `--sandbox danger-full-access` + `approval_policy=never`로 권한우회.
- **codex 버전 주의**: `gpt-6-astra`는 **CLI 0.153.4+** 필요.
- `scripts/mad-dispatch.sh <agy|codex|deepseek> …`가 전송 + Audit Packet을 자동 주입(권장 경로).

## 전제 점검 (첫 실행 시)

```sh
# 1) codex — CLI 최신인지 먼저 확인 (astra는 0.153.4+ 필요)
codex --version                       # < 0.153.4 이면: brew upgrade --cask codex
CODEX_HOME=~/.codex-nomcp codex exec --skip-git-repo-check -m gpt-6-astra \
  "reply with exactly: OK" </dev/null 2>&1 | tail -3

# 2) agy — 1.1.27+ 이어야 3.8 Flash가 존재
agy --version                         # < 1.1.27 이면: agy update
agy --model "Gemini 3.8 Flash (High)" -p "PONG" --dangerously-skip-permissions

# 3) deepseek — CLI 없음(API 전용). 키와 모델 노출 확인
curl -s https://api.deepseek.com/v1/models -H "Authorization: Bearer $(cat ~/.deepseek/api_key)" \
  | python3 -c "import json,sys;print([m['id'] for m in json.load(sys.stdin)['data']])"
  # 기대: deepseek-flash 포함(기본 모델 = V4.1 Flash). deepseek-v4-pro도 별도로 존재.
  # 옛 별칭(deepseek-reasoner/chat/v4-flash)은 전부 deepseek-flash로 떨어진다. deepseek-v4.1-flash는 400.

# 4) grok — CLI 직접(~/.grok/bin/grok). MCP 브리지(mcp__grok__*)는 구 CLI를 물고 426을 내므로 쓰지 않는다
grok -m grok-4.7 --reasoning-effort xhigh -p "Reply with exactly: PONG"
  # 기대: PONG. effort는 xhigh가 최상단(max는 거절). 한도·인증 실패면 그 라운드에서 제외하고 진행.
```
넷 다 확인한다. 없거나 미인증이면 사용자에게 알리고 진행 방식을 조정한다 — **codex·grok은 불가면 제외하고 나머지로 진행**(영구 규칙).
(`agy`가 없으면 `~/.local/bin`; deepseek 키는 `~/.deepseek/api_key`; grok은 `~/.grok/bin`.)

**버전이 로스터를 결정한다**: astra·3.8 Flash는 각각 특정 CLI 버전 이상에서만 존재한다.
"모델이 거부됐다"는 신호를 **모델 부재로 단정하지 말 것** — 먼저 CLI 버전부터 본다(2026-09-07 실측:
`gpt-6-astra`가 MCP 경로에서만 400을 냈고 원인은 구 바이너리를 물고 있던 서버 프로세스였다).

## 프로토콜 (단계)

`topic → position → critique → [spec-review (Gate 1)] → synthesis → ratify (Gate 2) → decision`

- 파일: 세션 디렉토리에 `NN-<phase>-<author>.md`. phase ∈ {topic, position, critique, spec, spec-review, synthesis, ratify, decision, audit}.
- 각 AI는 **독립적으로** position을 쓰고(상대 글 안 봄), critique부터 서로의 원문을 읽는다.
- **최소 2회 토론 라운드 권장 — 1왕복 확증 금지**: position→critique 1왕복만으로 synthesis에 가지 말 것. critique에서 나온 반론·교정을 반영한 **수정 position(또는 반박·재검증) 라운드를 최소 1회 더** 거친 뒤 종합한다. 한 번의 라운드는 첫 인상에 대한 상호 확증으로 수렴하기 쉽다 — 반론이 소화된 뒤에도 살아남는 주장만 decision에 올린다. 예외: 단순 수치 재현 확인 같은 경량 검증은 1라운드 가능하되, decision에 **라운드 수와 그 사유를 명기**한다. (실측 근거: 압축 연구 세션들에서 2~3라운드째에 결론을 뒤집는 교정이 반복 발견됨 — 이종 짝 비교, LOO leakage, k=4 전 조합 우위 반례 전부 후속 라운드 산출.)
- 라운드 내 **외부 AI 4종(codex·agy·deepseek·grok)은 병렬**(Bash run_in_background), **claude 독립 세션(Fable, Agent tool)도 같은 호출 묶음에서 동시 스폰**. 총 5자(불가로 빠진 외부는 제외)가 한 라운드를 동시에 돈다. 라운드 간은 순차.
> ### 🗣️ claude 몫은 **항상 독립 세션이** 낸다 — 오케스트레이터는 판단 산출을 직접 쓰지 않는다 (하드 규칙, 2026-09-22 개정)
> **모든 판단 라운드(position·critique·rebuttal·verify·audit·interp)에서 외부 AI 디스패치와 *별개로*
> claude 독립 세션을 **하나** 스폰한다: `model=fable`(Fable 5.1), 이전 맥락 없는 새 세션,
> **effort=max 고정**. 산출 파일 `NN-<phase>-claude-fable.md`.
> 이건 "권장"이 아니라 차단 규칙.**
> - **Fable 1세션 근거(2026-09-22 사용자 지시)**: Opus를 로스터에서 뺐다. 외부 4종(2026-10-06 grok 재합류)과 합쳐 **판단 주체 5자**가 된다.
>   같은 벤더 계열을 둘 돌려도 판단이 상관돼 독립 증거가 되지 못한다는 점이, 비용 대비 이득을 깎는다.
> - **구판(오케스트레이터가 Write로 인라인 작성) 폐지 근거(2026-07-13 실증)**: 코덱 재감사에서 claude 몫을
>   독립 세션으로 바꾸자, 그 세션이 라운드 2의 유일 P2를 적발 — 오케스트레이터가 측정 없이 closed 서명한
>   Claim Ledger 항목을 반례로 반증했다. **오케스트레이터 인라인 산출은 자기 서명을 자기 감사하지 못한다.**
> - **디스패치=참여 아님**: 외부만 띄우고 claude 세션을 빼먹은 채 synthesis로 가는 것은 **프로토콜 위반**.
>   각 판단 라운드 종료 조건 = {외부 산출 정족수 ≥2} **∧** {claude 독립 세션 산출 **1개**(Fable) 존재}.
> - **독립 세션 프롬프트 필수 요소**: ① 이전 맥락 없음 명시 ② read-set(원문 직접 열람) ③ **자체 재현 실행 요구**
>   (컴파일·게이트·harness — Bash 가용, 소스 수정·git 쓰기 금지) ④ **오케스트레이터 서술·수정·ledger의 과장·누락
>   적발을 명시 과제로** ⑤ 산출은 세션 디렉토리에 Write, 최종 응답은 요약+VERDICT만.
> - **노출 규칙**: position 라운드에서 claude 세션은 외부 AI의 글을 보지 않는다(외부 AI와 동일 규칙).
>   critique부터 상호 원문 열람.
> - **자기 규율(불변)**: ① synthesis에서 claude 산출 **우대 금지**(동일 비중 인용·대조). ② claude 산출·synthesis·
>   decision·spec도 ratify/Gate1 감사의 명시 대상. ③ 수렴 집계는 **벤더 계열 단위**로 센다 — 같은 계열의
>   일치는 독립 증거가 아니다.
> - **오케스트레이터의 실행 의무는 유지**: 결정 경로의 게이트 실행·raw 파싱·수치 재현은 오케스트레이터가 직접 한다.

- **⚠ 같은 라운드 재디스패치 = 격리 필수(2026-09-24 실측 오염)**: 라운드 도중 일부 참여자만 다시 돌릴 때
  (정지·실패 후 재실행), **이미 끝난 참여자의 같은 라운드 산출이 세션 디렉토리에 남아 있으면** Audit Packet이
  "직전 원문 전부"로 그것까지 읽혀 **라운드 내 독립성이 깨진다.**
  실측: critique 라운드에서 codex가 먼저 끝난 뒤 agy·deepseek를 재디스패치하자 둘 다 `06-critique-codex.md`를
  **전문** read-set에 올렸고, 10개 쟁점 중 5개에서 세 외부 모델이 **똑같이 "부분"**으로 수렴했다 — 독립 판정 3건이
  아니라 codex 1건의 반향이었다. **처방**: 이전 라운드 산출(예: topic + position)만 복사한 **격리 세션 디렉토리**를
  만들어 `.current-session`을 잠시 그쪽으로 돌린 뒤 재디스패치하고, 끝나면 산출을 본 세션으로 옮기고 포인터를
  복원한다. 오염본은 `*.CONTAMINATED.md`로 보존해 기록을 남긴다. **탐지**: synthesis 전 각 산출의 read-set에
  같은 라운드 동료 파일명이 있는지 `grep`으로 확인한다 — 판정 매트릭스가 벤더 무관하게 균일하면 오염을 의심하라.
- **새 세션은 반드시 `mad-new.sh`로 생성(또는 `discussion/.current-session` 갱신 확인) 후 디스패치** — 포인터 미갱신 시 산출이 직전 세션 파일을 덮어쓴다(2026-07-06 유실 사고).
- **★ 작업 맥락 동봉 의무(2026-07-26 사용자 지시)**: 디스패치 전 **세션 `00-topic.md`에 작업 맥락을 반드시 채운다**(파이프라인/프로젝트 목적, 관련 이력·수치, 이번 라운드가 판정할 결정과 대안, 판단 기준). `mad-dispatch.sh`가 00-topic.md **전문을 모든 AI 프롬프트에 인라인 동봉**한다(read-set 참조만으로는 빈 스텁·미열람 위험). 별도 맥락 파일을 쓰려면 `MAD_CONTEXT_FILE=<path>`로 override. 스텁 상태로 디스패치하는 것은 프로토콜 위반.

## 토큰 사용량 관측 (Plus 할당량 관리)

```sh
# 단발 측정
CODEX_HOME=~/.codex-nomcp codex exec --skip-git-repo-check --json -m gpt-6-astra "<프롬프트>" \
  </dev/null 2>/dev/null | tee /tmp/run.jsonl | "$SK/mad-usage.sh"

# 저장된 로그 집계 (여러 개 합산 가능)
"$SK/mad-usage.sh" /tmp/run1.jsonl /tmp/run2.jsonl
```

### 실측 벤치마크 (2026-09-07, `CODEX_HOME=~/.codex-nomcp`, 단일 턴)

| 축 | 모델 | 비캐시 입력 | 출력 | 추론 |
|---|---|---|---|---|
| 최소 호출(`Output only: X`) | astra | **3,324** | 5 | 0 |
| 최소 호출 | sol | **3,455** | 5 | 0 |
| 긴 출력(300줄 생성) | astra | 3,366 | 3,007 | 18 |
| 긴 출력 | sol | 3,855 | 3,165 | 59 |
| 어려운 추론(기본 effort) | astra | 5,001 | 917 | 76 |
| 어려운 추론(**xhigh**) | astra | 6,153 | 1,754 | 331 |

**읽는 법**
1. **고정 오버헤드가 지배한다** — 5토큰을 답하는 호출도 **비캐시 입력 3,300**을 쓴다. 시스템 프롬프트·
   도구 정의·스킬이 매 호출에 실리기 때문. **호출 수가 곧 비용**이다.
2. **astra가 sol보다 비싸지 않다** — 최소 호출·긴 출력 양쪽에서 오히려 조금 싸다.
   "astra는 토큰을 훨씬 많이 쓴다"는 통념은 이 측정으로 지지되지 않는다.
3. **effort는 추론을 키우지만 절대량이 작다** — 같은 문제에서 기본→xhigh: 추론 76→331,
   출력 917→1,754, 비캐시 입력 5,001→6,153. 배수는 크지만 절대값은 고정 오버헤드보다 작다.
4. **캐시 적중률 90%+** — 세션을 이어가면 이 비율이 유지된다. `resume`이 유리한 이유.

**할당량 가시성 — 없다**: JSONL 이벤트는 `thread.started`/`turn.started`/`item.*`/`turn.completed`뿐이고
rate limit·quota 필드가 없다. app-server 스키마에도 없다. **남은 할당량은 CLI로 알 수 없다.**
대신 **소모량은 정밀히 잴 수 있으므로**, `mad-usage.sh`의 `비캐시 입력 + 출력` 누적으로 관리한다.

**핵심 관측(2026-09-07 실측)**: `17*23`을 묻고 5토큰을 답한 호출이 **입력 16,250토큰**을 썼다
(그중 캐시 적중 12,160). 시스템 프롬프트·도구 정의·스킬이 **매 호출마다** 실리기 때문이다.

→ **짧은 호출을 여러 번 하는 쪽이 긴 호출 한 번보다 비싸다.** 출력이 길어서 할당량이 녹는 게 아니라
고정 입력 비용이 호출 수만큼 곱해진다. 라운드를 잘게 쪼개기보다 **한 세션에서 `resume`으로 이어가는 쪽**이
캐시 적중률을 올려 유리하다. `mad-usage.sh`의 `비캐시 입력`이 실질 영향분이다.

⚠ **effort는 상한이지 하한이 아니다** — 쉬운 질문에선 값을 올려도 추론 토큰이 늘지 않는다
(deepseek 실측: minimal 54 vs xhigh 56). 비용 예측을 effort 값만으로 하지 말 것.

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
printf '%s' "당신 입장을 ... 작성하라" > /tmp/p.txt
"$SK/mad-dispatch.sh" codex    01-position-codex.md    /tmp/p.txt   # gpt-6-astra, 기본 effort
"$SK/mad-dispatch.sh" agy      02-position-agy.md      /tmp/p.txt   # Gemini 3.8 Flash (High)
"$SK/mad-dispatch.sh" deepseek 03-position-deepseek.md /tmp/p.txt   # deepseek-flash, reasoning_effort=xhigh
"$SK/mad-dispatch.sh" grok     05-position-grok.md     /tmp/p.txt   # grok-4.7, xhigh — 일회용 복제본에서 실행, 산출을 세션으로 옮김
#    → Bash 툴에서 run_in_background=true 로 셋을 동시에 띄우고 mad-status로 폴링.
#    같은 호출 묶음에서 claude 독립 세션도 Agent tool로 동시 스폰(하드 규칙):
#      Agent(subagent_type='general-purpose', model='fable', ...) → 04-position-claude-fable.md
#      effort=max. 세션 effort가 max가 아니면 Workflow agent(..., {effort:'max'})로 강제.
#    deepseek 무거운 감사는 MAD_DISPATCH_TIMEOUT=600~900 권장.
#    MAD_DRY_RUN=1 로 명령만 미리보기 가능(세션이 있어야 동작).
#
#    override 환경변수:
#      MAD_CODEX_MODEL / MAD_CODEX_EFFORT      (기본: gpt-6-astra / 미지정=모델 기본)
#      MAD_AGY_MODEL                            (기본: Gemini 3.8 Flash (High))
#      MAD_DEEPSEEK_EFFORT / MAD_DEEPSEEK_TURNS (기본: xhigh / 40)

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
- **codex stall 주의**: `codex exec`도 설정에 등록된 다운스트림 MCP 서버 인증이 hang되면 멈춘다(증상: etime↑·CPU≈0). `mad-dispatch.sh`가 `CODEX_HOME=~/.codex-nomcp`로 띄워 MCP 로딩을 차단한다. 그래도 5분 이상 stall이면 mad-dispatch watchdog가 kill+retry. 수동 개입 시 `pkill -f 'codex exec'` 후 재디스패치. 무거운 작업은 `MAD_DISPATCH_TIMEOUT=900`. **단 "stall처럼 보임 = stall"로 단정 금지 — 아래 "실패 진단 프로토콜"의 PING으로 usage-limit과 구분한 뒤 행동**(빈 exit 1은 usage-limit 위장이 잦다).
- **⚠ agy 조용한 5분 타임아웃**: `agy -p`는 `--print-timeout` **기본 5분**이다. 무거운 감사는 이를 넘겨
  **로그 0바이트 · 산출 파일 없음**으로 죽는다. PING은 정상이라 stall/usage-limit로 **오진하기 쉽다**
  (2026-09-08 두 번 연속 실측). `mad-dispatch.sh`가 `MAD_DISPATCH_TIMEOUT`을 `--print-timeout`으로도
  전달하도록 고쳤다. 수동 호출 시 반드시 `--print-timeout`을 명시할 것.
- **에이전트 side-effect 금지**: codex는 권한우회(full access) 상태라 워크스페이스 CLAUDE.md의 "커밋·push" 지시를 오독해 자율 커밋/푸시할 수 있다(2026-07-03 실제 발생, force-push로 수습). Audit Packet에 "git 쓰기·소스 수정 금지, 산출 파일만" 규칙을 넣어 차단했다 — 유지할 것. 디스패치 후 `git log`로 유령 커밋 확인 권장.
- **⚠ 실패 진단 프로토콜 — 어떤 비정상 종료든 원인 추정 금지, PING으로 분류 후 행동**: 외부 AI가 산출 파일 없이 죽으면(빈 출력, exit 1, exit 3, exit 143/kill, timeout, stall 무엇이든) **"transient"·"일시적"으로 추정하고 넘어가지 말 것.** 반드시 아래 결정 트리를 실행한다.
  1. **PING**: `CODEX_HOME=~/.codex-nomcp codex exec --skip-git-repo-check "reply with exactly: OK" </dev/null 2>&1 | tail`. (agy는 `agy --model '...' -p PONG --dangerously-skip-permissions`; deepseek는 `/v1/models` curl로 키·모델 확인; grok은 `grok -m grok-4.7 --reasoning-effort xhigh -p "Reply with exactly: PONG"`.)
  2. **PING이 usage-limit 신호**("hit your usage limit"·"try again at …"·429·quota)를 뱉으면 → **usage limit 확정**. 재시도 금지(quota만 소모). **그 AI만 제외하고 나머지 멤버 전원으로 진행**(정족수 2 이상 유지 확인). agy·deepseek은 회복시각이 세션 내(수 시간)면 `CronCreate`로 복귀도 병행. **codex·grok은 복귀를 예약하지 않는다 — 제외로 확정하고 그 라운드를 닫는다**(로스터 변경 이력의 2026-10-03·2026-10-06 영구 규칙).
  3. **PING이 정상 응답(OK)**이면 → 직전 실패는 stall/transient였음이 *증명됨*. 그때만 kill 후 1회 재디스패치.
  4. **PING 자체가 hang**이면 → stall 확정. `pkill -f 'codex exec'` 후 재디스패치 1회, 그래도면 제외하고 나머지로 진행.
  - **핵심**: `mad-dispatch.sh`의 usage-limit 자동감지는 codex가 MCP isError로 **빈 출력 exit 1**로 죽으면 우회된다(2026-07-04·2026-07-06 두 번 실측). 그래서 **exit 코드만 보고 원인을 부르는 것이 반복 실패의 근원** — exit 1이든 143이든 **PING 분류가 유일한 진실 소스**다. PING을 건너뛰면 usage-limit을 stall로 오판해 대타를 안 넣고 정족수 미달로 종합하게 된다(위 정족수 게이트 위반).
  - 다른 AI 산출물은 이미 있으면 재실행 불필요.
- **결정론은 스크립트로**: 세션 생성·디스패치·게이트는 손으로 하지 말고 스크립트로(누락 방지).

## think-deep 와의 차이

`think-deep`은 Claude 서브에이전트 3개의 내부 토론이다. 이 skill은 **서로 다른 벤더의 외부 AI 4종
(codex·agy·deepseek·grok)을 실제로 구동**하고 여기에 **Claude 독립 세션(Fable)** 을 더해
총 5자로 교차검증하며, 오케스트레이터 자신을 감사하는 게이트를 강제한다.

**교차 모델의 요점**: 같은 모델이 탐색하고 같은 모델이 반증하면 그 계열의 맹점은 양쪽에서 동시에
비어 있다 — "반증에 실패했다"가 "실재한다"를 뜻하지 못한다. 벤더가 다른 4종을 섞는 이유가 이것이고,
같은 이유로 **같은 벤더 계열의 일치는 독립 증거로 세지 않는다**(상관된 판단). 수렴 집계에서 계열을 구분해 센다.
