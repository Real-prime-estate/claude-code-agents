---
name: think-deep
description: 복잡한 질문에 대해 3개 전문 에이전트(연구/논리/창의비판)가 파일 기반으로 토론하고 수렴된 결론을 취합하는 멀티 에이전트 토론 시스템
metadata:
  priority: 8
  promptSignals:
    phrases:
      - "think-deep"
      - "깊이 생각"
      - "토론해"
      - "여러 관점"
      - "다각도"
    anyOf:
      - "비교"
      - "장단점"
      - "트레이드오프"
      - "어떤 방식"
      - "어떤 게 나아"
      - "아키텍처"
      - "설계"
    noneOf:
      - "파일 수정"
      - "코드 작성"
      - "버그 수정"
      - "커밋"
    minScore: 5
---

# Think-Deep: 멀티 에이전트 토론 시스템

복잡한 질문에 대해 3개의 전문 에이전트가 토론하고, 수렴된 결론을 최종 취합합니다.

## 에이전트 모델 설정

모든 서브에이전트는 기본적으로 **opus** (Claude Opus 4.6)로 실행한다.
깊은 추론과 코드 탐색이 필요한 토론의 특성상 최고 수준 모델이 필요하다.

## 인자 파싱

사용자 입력: `$ARGUMENTS`

옵션 파싱:
- `--rounds N`: 최대 라운드 수 (기본: 3)
- `--verbose`: 전체 토론 로그 출력
- 나머지: 토론할 질문

## 라운드 출력 템플릿

각 에이전트가 라운드 결과를 작성할 때 사용하는 형식:

```markdown
## 의견 (Opinion)
[이 질문에 대한 핵심 주장을 명확하게 서술]

## 근거 (Evidence)
[주장을 뒷받침하는 근거, 사실, 분석 결과를 나열]

## 다른 에이전트 평가 (Peer Review)
[2라운드부터 작성. 각 에이전트의 의견에 대해 동의/반박/보완 의견을 제시]
- 연구 에이전트에 대해: [평가]
- 논리 에이전트에 대해: [평가]
- 창의/비판 에이전트에 대해: [평가]

## 합의 상태 (Consensus)
- 합의: [다른 에이전트들과 동의하는 포인트]
- 미합의: [아직 의견이 다른 포인트]

## 확신도 (Confidence)
[1-10 숫자. 1=매우 불확실, 10=완전 확신]
```

## 실행 프로토콜

### Phase 0: 준비

1. 토론 디렉토리를 생성한다:
   ```
   Bash: mkdir -p ~/Agents/debates/$(date +%Y-%m-%d_%H%M%S)/round-1
   ```
   생성된 경로를 `DEBATE_DIR`로 기억한다.

2. 플러그인 디렉토리를 찾는다:
   ```
   Bash: find ~/.claude/plugins/cache -path "*/claude-code-agents/*/prompts/orchestrator.md" -type f 2>/dev/null | head -1 | xargs dirname | xargs dirname
   ```
   찾은 경로를 `PLUGIN_DIR`로 기억한다. 찾지 못하면 `~/.claude/plugins/cache` 아래에서 `agents/*/prompts/orchestrator.md`로 재탐색한다.

### Phase 1: 라운드 1 (병렬 실행)

Agent 도구로 3개의 서브에이전트를 **동시에** 실행한다. `subagent_type`을 사용하여 에이전트 정의를 자동 로드한다:

```
Agent(
  subagent_type="agents:researcher",
  description="연구 에이전트 라운드 1",
  prompt="
    ## 토론 질문
    [사용자의 질문]

    ## 라운드: 1 (초기 의견 제시)
    이 질문에 대한 당신의 전문적 의견을 제시하세요.

    ## 출력 형식
    [위의 라운드 출력 템플릿 전문]

    ## 주의사항
    - '다른 에이전트 평가' 섹션은 라운드 1에서는 '해당 없음 (1라운드)'이라고 작성
    - 반드시 Write 도구로 결과를 다음 파일에 저장: {DEBATE_DIR}/round-1/researcher.md
    - 모든 응답은 한국어로 작성
  "
)
```

3개 Agent를 **병렬로** 실행:
- Agent(subagent_type="agents:researcher", description="연구 에이전트 라운드 1", ...)
- Agent(subagent_type="agents:logician", description="논리 에이전트 라운드 1", ...)
- Agent(subagent_type="agents:creative-critic", description="창의비판 에이전트 라운드 1", ...)

### Phase 2: 수렴 확인

3개 에이전트가 모두 완료되면:

1. 각 에이전트의 출력 파일을 읽는다:
   - Read: `{DEBATE_DIR}/round-1/researcher.md`
   - Read: `{DEBATE_DIR}/round-1/logician.md`
   - Read: `{DEBATE_DIR}/round-1/creative-critic.md`

2. **조기 종료 판단**: 3개 에이전트의 핵심 결론이 실질적으로 동일하면 → Phase 4로 직행

3. 그렇지 않으면 → Phase 3으로

### Phase 3: 추가 라운드 (라운드 2+)

현재 라운드를 `N`이라 하자 (2부터 시작).

1. 라운드 디렉토리 생성:
   ```
   Bash: mkdir -p {DEBATE_DIR}/round-{N}
   ```

2. 3개 에이전트를 **동시에** 실행. `subagent_type`을 사용하며, 이전 라운드의 모든 에이전트 출력을 프롬프트에 포함:

```
Agent(
  subagent_type="agents:researcher",
  description="연구 에이전트 라운드 {N}",
  prompt="
    ## 토론 질문
    [사용자의 질문]

    ## 라운드: {N}

    ## 이전 라운드 결과

    ### 연구 에이전트의 의견 (라운드 {N-1}):
    [researcher.md 내용 전문]

    ### 논리 에이전트의 의견 (라운드 {N-1}):
    [logician.md 내용 전문]

    ### 창의/비판 에이전트의 의견 (라운드 {N-1}):
    [creative-critic.md 내용 전문]

    ## 지시사항
    1. 다른 에이전트의 의견을 읽고 평가하라
    2. 동의하는 부분과 반박할 부분을 명확히 하라
    3. 이전 라운드의 피드백을 반영하여 의견을 발전시켜라
    4. '합의 상태'를 정확히 업데이트하라

    ## 출력 형식
    [위의 라운드 출력 템플릿 전문]

    ## 주의사항
    - 반드시 Write 도구로 결과를 다음 파일에 저장: {DEBATE_DIR}/round-{N}/researcher.md
    - 모든 응답은 한국어로 작성
  "
)
```

3. 라운드 완료 후 수렴 판단:

```
수렴 조건 (하나라도 충족 시 Phase 4로):
  A. 모든 에이전트 확신도 >= 7 AND 미합의 포인트 = 0
  B. 현재 라운드 >= 최대 라운드 수 (기본 3, --rounds로 변경 가능)
```

4. 수렴하지 않으면 → N을 증가시키고 Phase 3 반복

### Phase 4: 최종 답변 생성

1. 오케스트레이터 프로토콜을 읽는다:
   - Read: `{PLUGIN_DIR}/prompts/orchestrator.md`

2. **오케스트레이터 프로토콜에 따라** 마지막 라운드의 3개 에이전트 출력을 취합한다:

   - 1단계: 합의 지도 작성 (만장일치/다수/논쟁/철회 분류)
   - 2단계: 확신도 가중 평가 (가장 낮은 확신도의 근거를 우선 검토)
   - 3단계: 충돌 조율 (사실→연구, 논리→논리, 프레임→창의 우선)
   - 4단계: 우선순위 결정 (합의도 × 확신도 × ROI)
   - 5단계: 최종 답변 구성 (합의 권고 + 논쟁 항목 + 철회 + 핵심 통찰)

3. `--verbose` 옵션이 있으면 모든 라운드의 토론 내용을 접을 수 있는 형태로 포함:

```markdown
<details>
<summary>전체 토론 로그 (라운드 1-{N})</summary>

### 라운드 1
[각 에이전트 출력 전문]

### 라운드 2
[각 에이전트 출력 전문]
...

</details>
```

4. **보고서를 저장한다**: 오케스트레이터 프로토콜 6단계에 따라 최종 답변을 `{DEBATE_DIR}/report.md`로 Write한다.

5. 토론 디렉토리는 `~/Agents/debates/` 아래에 보존된다. 삭제하지 않는다.

## 복잡도 자동 판단 가이드

이 스킬이 promptSignals로 자동 주입되었을 때, 다음 기준으로 실제 실행 여부를 판단한다:

**실행해야 하는 경우:**
- "A vs B" 비교, 장단점 분석
- 아키텍처/설계 결정
- 정답이 하나가 아닌 열린 질문
- 트레이드오프 분석이 필요한 기술 선택

**실행하지 않는 경우 (스킬 무시):**
- 단순 코드 작성/편집 요청
- 명확한 사실 확인 질문 (예: "Python에서 리스트 정렬하는 방법은?")
- 명확한 버그 수정
- 파일 조작/편집 요청
- 단순한 설명 요청

자동 주입이지만 실행하지 않기로 판단한 경우, 스킬을 무시하고 일반적으로 답변한다.
