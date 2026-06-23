# claude-code-agents

멀티 에이전트 토론 시스템 + 멀티-AI 협업 오케스트레이션 + 언어별 코드 실행 에이전트를 제공하는 [Claude Code](https://claude.ai/code) 플러그인입니다.

## 기능

### 토론 / 협업

| 스킬 | 설명 |
|------|------|
| `/think-deep` | 3개 에이전트(연구/논리/창의비판)가 파일 기반 다중 라운드 토론 후 수렴된 결론 생성 |
| `/multi-ai-debate` | Claude(오케스트레이터)가 codex(GPT-5.5)·agy(Gemini)를 Bash로 구동해 파일 기반 토론·구현·검증. 할루시네이션 방지 게이트(Claim Ledger / spec-review / synthesis 비준 / red-team) 강제 |

### 코드 실행

| 스킬 | 설명 |
|------|------|
| `/code` | 프로젝트 언어·파일 유형(SwiftUI View 포함) 자동 감지 → 해당 executor 에이전트 스폰 + 컨벤션 리뷰 |

### 에이전트 목록

**토론 에이전트 (think-deep):**
- `think-deep-researcher` — 사실 확인, 정보 탐색, 근거 수집, 웹 검색
- `think-deep-logician` — 논리적 일관성 검증, 기술적 타당성 분석, 트레이드오프 평가
- `think-deep-critic` — 대안 제시, 기존 의견 비판, 프레임 전환

**코드 실행 에이전트:**
- `c-executor` — C11, Linux kernel 스타일
- `cpp-executor` — C++20, Core Guidelines, CMake/clang-format/clang-tidy
- `ts-executor` — TypeScript strict, 보수적 안전성 컨벤션
- `next-react-executor` — Next.js App Router / React / TSX, strict TypeScript, ESLint
- `py-executor` — Python 3.12+, mypy strict, Ruff, uv
- `swift-executor` — Swift 6.0+, Apple API Design Guidelines, Concurrency
- `swiftui-designer-executor` — SwiftUI View, HIG, Dark Mode, Dynamic Type, 접근성
- `kotlin-executor` — Kotlin, coroutines, ktlint

## 메모리 (memory/)

작업 방식 지침(feedback)과 언어별 코딩 컨벤션을 추린 참조용 메모리. executor 에이전트가 코드 작성·리뷰 시 정본으로 참조하는 컨벤션 7종과, 사용자가 확정한 작업 방식 지침 11종이 들어 있다. 자세한 목록은 [memory/MEMORY.md](memory/MEMORY.md).

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

# 멀티-AI 협업 (codex + gemini 오케스트레이션)
/multi-ai-debate "결제 모듈 설계 교차검증"

# 코드 실행
/code "로그인 API 엔드포인트 구현"
/code --lang swift "네트워크 매니저 리팩토링"
```

## 구조

```
.claude-plugin/
  plugin.json          # 플러그인 메타데이터
agents/                # 에이전트 정의 (11개)
skills/                # 스킬 정의 (3개: code, think-deep, multi-ai-debate)
memory/
  MEMORY.md            # 메모리 인덱스
  coding-conventions/  # 언어별 코딩 컨벤션 (7개)
  feedback/            # 작업 방식 지침 (11개)
```

## 라이선스

MIT
