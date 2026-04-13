# claude-code-agents

멀티 에이전트 토론 시스템 + 언어별 코드 실행 에이전트 + 프로젝트 분석 파이프라인을 제공하는 [Claude Code](https://claude.ai/code) 플러그인입니다.

## 기능

### 토론 시스템

| 스킬 | 설명 |
|------|------|
| `/think-deep` | 3개 에이전트(연구/논리/창의비판)가 다중 라운드 토론 후 수렴된 결론 생성 |
| `/design-think` | 4개 에이전트(UX/비주얼/SwiftUI/비평가)가 SwiftUI 디자인 토론 수행 |

### 코드 실행

| 스킬 | 설명 |
|------|------|
| `/code` | 프로젝트 언어 자동 감지 → 해당 executor 에이전트 스폰 |
| `/pipeline` | think-deep 보고서의 합의 권고를 자동 분류 후 executor에 전달 |

### 프로젝트 분석

| 스킬 | 설명 |
|------|------|
| `/analyze` | 프로젝트 아키텍처, 기술 스택, 코드 품질 분석 |

### 에이전트 목록

**토론 에이전트:**
- `researcher` — 사실 확인, 정보 탐색, 근거 수집, 웹 검색
- `logician` — 논리적 일관성 검증, 기술적 타당성 분석
- `creative-critic` — 대안 제시, 기존 의견 비판, 프레임 전환

**디자인 토론 에이전트:**
- `ux-designer` — 사용자 플로우, 인터랙션, 접근성
- `visual-designer` — 타이포, 컬러, 간격, 시각적 계층, HIG
- `swiftui-architect` — 구현 가능성, 성능, Swift 6
- `design-critic` — 가정 도전, ROI, 대안

**코드 실행 에이전트:**
- `c-executor` — C11, Linux kernel 스타일
- `ts-executor` — TypeScript strict, Biome
- `py-executor` — Python 3.12+, mypy strict, Ruff, uv
- `swift-executor` — Swift 6.0+, Apple API Design Guidelines
- `swiftui-designer-executor` — SwiftUI View, HIG, Dark Mode, 접근성
- `kotlin-executor` — Kotlin, coroutines, ktlint

**유틸리티 에이전트:**
- `project-analyzer` — 프로젝트 구조 및 품질 분석
- `debugger` — 에러 근본 원인 추적 및 수정안 제시
- `reviewer` — 코드 리뷰 (로직, 보안, 성능, 엣지 케이스)

## 설치

```bash
claude /plugin install claude-code-agents@<marketplace-name>
```

또는 이 저장소를 직접 플러그인으로 설치:

```bash
claude /plugin install --from-github Real-prime-estate/claude-code-agents
```

## 사용법

```bash
# 멀티 에이전트 토론
/think-deep "Redis vs PostgreSQL pub/sub 비교"
/think-deep --rounds 5 "마이크로서비스 vs 모놀리스"

# SwiftUI 디자인 토론
/design-think "설정 화면 레이아웃"

# 코드 실행
/code "로그인 API 엔드포인트 구현"
/code --lang swift "네트워크 매니저 리팩토링"

# 토론 결과 자동 구현
/pipeline ~/Agents/debates/2026-04-07_021840/report.md

# 프로젝트 분석
/analyze
/analyze --full
```

## 구조

```
.claude-plugin/
  plugin.json          # 플러그인 메타데이터
agents/                # 에이전트 정의 (16개)
skills/                # 스킬 정의 (5개)
prompts/
  orchestrator.md      # 토론 취합 프로토콜
templates/
  round-output.md      # 라운드별 출력 형식
  final-output.md      # 최종 답변 형식
```

## 라이선스

MIT
