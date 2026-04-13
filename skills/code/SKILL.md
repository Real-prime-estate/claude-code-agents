---
name: code
description: 프로젝트 언어 및 파일 유형(SwiftUI View 포함)을 자동 감지하여 해당 실행 에이전트를 스폰하고 코드 작성 + 컨벤션 리뷰를 수행
metadata:
  priority: 7
  promptSignals:
    phrases:
      - "코드 작성"
      - "구현해"
      - "수정해"
      - "코딩해"
    anyOf:
      - "함수"
      - "클래스"
      - "모듈"
      - "리팩토링"
      - "View"
      - "화면"
    noneOf:
      - "토론"
      - "비교"
      - "think-deep"
      - "design-think"
    minScore: 5
---

# Code: 언어/파일 유형별 실행 에이전트 시스템

프로젝트 언어와 파일 유형을 자동 감지하여 해당 실행 에이전트를 직접 스폰합니다. 에이전트는 플러그인에 등록된 첫 번째 클래스 에이전트입니다 (`agents:*-executor`).

## 사용 가능한 에이전트

| subagent_type | 대상 | 모델 | 주요 용도 |
|---------------|------|------|----------|
| `agents:c-executor` | C 코드 | opus | 일반 C |
| `agents:ts-executor` | TypeScript 코드 | opus | 일반 TS |
| `agents:py-executor` | Python 코드 | opus | 일반 Python |
| `agents:swift-executor` | Swift 코드 (비-View) | opus | 모델, 로직, 서비스 |
| `agents:swiftui-designer-executor` | SwiftUI View | opus | View, 레이아웃, 스타일, 애니메이션 |
| `agents:kotlin-executor` | Kotlin 코드 | opus | 일반 Kotlin |

## 인자 파싱

사용자 입력: `$ARGUMENTS`

옵션:
- `--lang <언어>`: 언어 명시 (c, ts, py, swift, swiftui, kotlin)
- `--from-debate <경로>`: think-deep 또는 design-think report.md에서 권고 구현
- `--review-only`: 코드 수정 없이 컨벤션 리뷰만
- 나머지: 코딩 지시

## 실행 프로토콜

### Phase 0: 언어 및 파일 유형 감지

1. **`--lang` 명시**:
   - `swift` → 일반 Swift (swift-executor)
   - `swiftui` → SwiftUI View (swiftui-designer-executor)
   - 기타 → 해당 executor

2. **명시 없으면 작업 디렉토리 스캔**:
   ```
   Makefile, CMakeLists.txt → C
   package.json, tsconfig.json → TypeScript
   pyproject.toml, uv.lock → Python
   Package.swift, *.xcodeproj → Swift 프로젝트
   build.gradle.kts → Kotlin
   ```

3. **Swift 프로젝트인 경우 추가 판단**:
   - 지시가 **View 레이어**에 관한 것이면 → `swiftui-designer-executor`
     - 힌트: "View", "화면", "레이아웃", "컴포넌트", "버튼", "리스트", "네비게이션", "애니메이션", "색상", "스타일", "스페이싱"
   - **비-View 로직/모델/서비스**이면 → `swift-executor`
     - 힌트: "모델", "서비스", "네트워크", "파싱", "로직", "계산", "저장소"
   - 불분명하면 → 대상 파일을 Read하여 `View` 프로토콜 준수 여부로 판단
   - 여전히 불분명하면 → 사용자에게 질문

4. **복수 언어 감지** → 지시 내용으로 해당 언어 선택. 불분명하면 질문

5. **감지 실패** → 사용자에게 질문

### Phase 1: report.md 연동 (선택)

`--from-debate <경로>` 옵션이 있으면:
1. Read: 해당 report.md
2. "합의된 권고" 섹션에서 구현 항목 추출
3. design-think 보고서이면 → `swiftui-designer-executor`로 라우팅 (기본)
4. think-deep 보고서이면 → 항목별 언어 감지 후 각 executor로 분배

### Phase 2: 에이전트 실행

Agent 도구로 해당 executor를 직접 스폰:

```
Agent(
  subagent_type="agents:{executor 이름}",
  description="{executor}: {지시 요약}",
  prompt="
    ## 작업 지시
    [사용자의 코딩 지시 또는 report.md 권고]

    ## 작업 디렉토리
    [현재 작업 디렉토리]

    ## 관련 파일
    [수정/생성 대상 파일 경로 — Read나 Edit의 대상]

    ## 추가 컨텍스트
    [report.md 내용, 분석가 컨텍스트, 기타]

    ## 주의사항
    - 반드시 상세 컨벤션 파일을 Read하라 (에이전트 정의에 명시된 경로)
    - 코드 작성 후 자체 리뷰 체크리스트를 수행하라
    - 모든 응답은 한국어로 작성
  "
)
```

에이전트 정의에 `model: opus`, `tools: ...`가 이미 포함되어 있으므로 `model` 인자는 생략 가능.

### Phase 3: 멀티 언어/유형 처리

복수 언어/유형이 필요한 경우:
1. 오케스트레이터(메인 세션)가 지시를 분리
2. 각 executor를 **순차** 실행 (파일 충돌 방지)
3. 언어/유형 간 인터페이스가 있으면 선행 결과를 후행 컨텍스트로 전달

**예시**: SwiftUI 화면 + ViewModel
1. `swift-executor`: ViewModel (@Observable 클래스) 구현
2. `swiftui-designer-executor`: View 구현 (ViewModel 타입 참조)

### Phase 4: --review-only 모드

`--review-only` 옵션이 있으면:
1. 에이전트 프롬프트를 "컨벤션 리뷰만 수행, 코드 수정 금지"로 변경
2. 에이전트가 기존 코드를 Read하고 위반 사항만 보고

## 복잡도 자동 판단

**실행:**
- "이 함수를 수정해", "새 모듈을 만들어"
- "설정 화면 만들어", "버튼 스타일 바꿔" (→ swiftui-designer-executor)
- "리팩토링해", "버그 수정해"

**무시:**
- "이 코드가 뭘 하는지 설명해" (설명 요청)
- "A vs B 비교" (→ think-deep 또는 design-think)
- "화면 구성 토론" (→ design-think)
