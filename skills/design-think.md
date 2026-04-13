---
name: design-think
description: SwiftUI 프론트엔드 디자인 질문에 대해 4개 전문 에이전트(UX/비주얼/SwiftUI/비평가)가 다중 라운드 토론을 수행하는 디자인 전용 토론 시스템
metadata:
  priority: 7
  promptSignals:
    phrases:
      - "design-think"
      - "디자인 토론"
      - "UI 설계"
      - "화면 설계"
    anyOf:
      - "SwiftUI"
      - "UI"
      - "화면"
      - "디자인"
      - "레이아웃"
      - "컴포넌트"
    noneOf:
      - "코드 작성"
      - "구현해"
      - "수정해"
    minScore: 6
---

# Design-Think: SwiftUI 디자인 토론 시스템

SwiftUI 프론트엔드 디자인 질문에 대해 4개 전문 에이전트가 토론하고, 수렴된 결론을 최종 취합합니다.

## 에이전트 구성

| 에이전트 | subagent_type | 모델 | 역할 |
|---------|---------------|------|------|
| ux-designer | agents:ux-designer | sonnet | 사용자 플로우, 인터랙션, 접근성 |
| visual-designer | agents:visual-designer | opus | 타이포, 컬러, 간격, 시각적 계층, HIG |
| swiftui-architect | agents:swiftui-architect | sonnet | 구현 가능성, 성능, Swift 6 |
| design-critic | agents:design-critic | opus | 가정 도전, ROI, 대안 |

## 인자 파싱

사용자 입력: `$ARGUMENTS`

옵션:
- `--rounds N`: 최대 라운드 수 (기본 3)
- `--verbose`: 전체 토론 로그 출력
- 나머지: 토론할 디자인 질문/요구사항

## 라운드 출력 템플릿

```markdown
## 의견 (Opinion)
[이 질문에 대한 핵심 주장을 명확하게 서술]

## 근거 (Evidence)
[주장을 뒷받침하는 근거, 사실, 분석 결과를 나열]

## 다른 에이전트 평가 (Peer Review)
[2라운드부터 작성. 각 에이전트의 의견에 대해 동의/반박/보완 의견을 제시]
- UX 에이전트에 대해: [평가]
- 비주얼 에이전트에 대해: [평가]
- SwiftUI 에이전트에 대해: [평가]
- 비평가에 대해: [평가]

## 합의 상태 (Consensus)
- 합의: [다른 에이전트들과 동의하는 포인트]
- 미합의: [아직 의견이 다른 포인트]

## 확신도 (Confidence)
[1-10 숫자. 1=매우 불확실, 10=완전 확신]
```

## 실행 프로토콜

### Phase 0: 준비

1. 토론 디렉토리 생성:
   ```
   Bash: mkdir -p ~/Agents/debates/design/$(date +%Y-%m-%d_%H%M%S)/round-1
   ```
   생성된 경로를 `DEBATE_DIR`로 기억.

2. 플러그인 디렉토리를 찾는다:
   ```
   Bash: find ~/.claude/plugins/cache -path "*/claude-code-agents/*/prompts/orchestrator.md" -type f 2>/dev/null | head -1 | xargs dirname | xargs dirname
   ```
   찾은 경로를 `PLUGIN_DIR`로 기억한다.

### Phase 1: 라운드 1 (병렬 실행)

4개 Agent를 **동시에** `subagent_type`으로 실행. 각 에이전트 프롬프트:

```
Agent(
  subagent_type="agents:ux-designer",
  description="UX 에이전트 라운드 1",
  prompt="
    ## 토론 질문
    [사용자 입력]

    ## 라운드: 1 (초기 의견 제시)
    이 질문에 대한 당신의 전문적 의견을 제시하세요.

    ## 출력 형식
    [위의 라운드 출력 템플릿 전문]

    ## 주의사항
    - '다른 에이전트 평가' 섹션은 라운드 1에서 '해당 없음 (1라운드)'이라고 작성
    - 반드시 Write 도구로 결과를 저장: {DEBATE_DIR}/round-1/ux-designer.md
    - 모든 응답은 한국어로 작성
  "
)
```

병렬 스폰:
- Agent(subagent_type="agents:ux-designer", ...)
- Agent(subagent_type="agents:visual-designer", ...)
- Agent(subagent_type="agents:swiftui-architect", ...)
- Agent(subagent_type="agents:design-critic", ...)

### Phase 2: 수렴 확인

4개 파일을 Read하여:
1. 조기 종료 판단: 4개 에이전트 핵심 결론이 실질적으로 동일하면 → Phase 4
2. 그렇지 않으면 → Phase 3

### Phase 3: 추가 라운드 (R2+)

현재 라운드를 N이라 하자.

1. 라운드 디렉토리 생성
2. 4개 에이전트를 **동시에** `subagent_type`으로 실행. 이전 라운드의 4개 출력을 프롬프트에 포함:

```
Agent(
  subagent_type="agents:ux-designer",
  description="UX 에이전트 라운드 {N}",
  prompt="
    ## 토론 질문
    [사용자 입력]

    ## 라운드: {N}

    ## 이전 라운드 결과
    ### ux-designer (R{N-1}):
    [내용]

    ### visual-designer (R{N-1}):
    [내용]

    ### swiftui-architect (R{N-1}):
    [내용]

    ### design-critic (R{N-1}):
    [내용]

    ## 지시사항
    1. 다른 에이전트의 의견을 읽고 평가하라
    2. 동의/반박을 명확히 하라
    3. 이전 라운드 피드백을 반영하여 의견을 발전시켜라
    4. '합의 상태' 업데이트

    ## 출력 형식
    [위의 라운드 출력 템플릿 전문]

    ## 주의사항
    - Write: {DEBATE_DIR}/round-{N}/ux-designer.md
    - 한국어
  "
)
```

3. 라운드 후 수렴 판단:
   - A. 모든 에이전트 확신도 >= 7 AND 미합의 포인트 = 0
   - B. 현재 라운드 >= 최대 라운드 수
4. 수렴 안 되면 N 증가 후 반복

### Phase 4: 최종 답변 생성 (오케스트레이터 프로토콜)

Read: `{PLUGIN_DIR}/prompts/orchestrator.md`

5단계 취합:
1. 합의 지도 작성 (만장일치/다수/논쟁/철회 4분류)
2. 확신도 가중 평가 (가장 낮은 확신도 우선 검토)
3. 충돌 조율:
   - 사용성 충돌 → ux-designer 우선
   - 시각 충돌 → visual-designer 우선
   - 기술 충돌 → swiftui-architect 우선
   - 프레임 충돌 → design-critic 우선
4. 우선순위 결정 (합의도 × 확신도 × ROI)
5. 최종 답변 구성

### Phase 5: 보고서 저장

Write: `{DEBATE_DIR}/report.md`

형식:
```markdown
# Design-Think 토론 보고서

> 주제: [토론 질문]
> 일시: [날짜]
> 라운드: [총 라운드 수]
> 에이전트: UX / Visual / SwiftUI / Critic

## 에이전트 요약
[각 에이전트 최종 입장 1-2줄]

## 합의된 권고
[합의 권고 + 근거 + 시각적 리스크 + 검증 방법]

## 논쟁 중인 항목
[찬성/반대/오케스트레이터 판단]

## 철회된 제안
[토론 중 철회된 것들]

## 핵심 통찰
[라운드를 거치며 발견된 통찰]

## 구체적 디자인 사양 (있으면)
[spacing, 타이포, 컬러 등 구체적 값]

## 메타데이터
- 합의율
- 평균 확신도
- 입장 변경
```

## 복잡도 자동 판단

**실행:**
- "이 화면 어떻게 설계?"
- "A 레이아웃 vs B 레이아웃"
- "인터랙션 패턴 뭐가 좋을까"
- "SwiftUI로 어떻게 구현?"

**무시:**
- "이 코드 구현해" (→ swift-executor)
- "이 코드 설명해" (설명 요청)
- "기술 선택 토론" (→ think-deep)
