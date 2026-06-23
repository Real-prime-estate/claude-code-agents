# MEMORY

작업 방식 지침(feedback)과 언어별 코딩 컨벤션만 추린 메모리 사본. 프로젝트별 상태·리소스 포인터(project/reference/user)는 제외했다.

## 코딩 컨벤션 (coding-conventions/)

언어별 실행 에이전트(`*-executor`)가 코드 작성·자체 리뷰 시 정본으로 참조하는 컨벤션.

- [C](coding-conventions/c.md) — Linux kernel 스타일 + C11
- [C++](coding-conventions/cpp.md) — Core Guidelines + C++20, CMake/clang-format/clang-tidy
- [TypeScript](coding-conventions/typescript.md) — strict 전부 켠 보수적 안전성, unsoundness/JS 함정 차단
- [Next.js / React / TSX](coding-conventions/next-react.md) — App Router 현실 반영, typescript.md 위에 얹음
- [Python](coding-conventions/python.md) — 3.12+, mypy strict, Ruff, uv
- [Swift](coding-conventions/swift.md) — Swift 6.0+, API Design Guidelines, Concurrency
- [SwiftUI](coding-conventions/swiftui.md) — Apple HIG, 디자인 토큰, 접근성

## 작업 방식 지침 (feedback/)

사용자가 정정·확정한 작업 방식. 일부는 특정 프로젝트 맥락에서 도출됐으나 지침 자체는 일반적으로 적용.

- [헬퍼 최소화](feedback/minimize-low-level-helpers.md) — 저수준 헬퍼 선제 생성 금지, 반복 증명 후에만 추출
- [헬퍼 자기심문](feedback/feedback-helper-self-interrogation.md) — 추상화 도입 직전 8항목 체크리스트 통과·보고
- [헬퍼는 최적화 목적만](feedback/feedback-helpers.md) — 측정 가능한 성능 이득 없으면 헬퍼 X
- [큰 코드 위임](feedback/delegate-large-code.md) — 큰 코드는 executor 에이전트 위임, 작은 것은 직접
- [질문은 AUQ로](feedback/feedback-communication.md) — 모든 질문은 AskUserQuestion으로 2~4개 묶어서
- [설계 자기심문](feedback/feedback-self-inquiry.md) — 데이터 모델·객체화 결정 시 자기심문 체크리스트
- [작업 후 항상 커밋](feedback/always-commit-after-task.md) — 작업 단위 완료 시 크기 무관 먼저 커밋
- [MSVC는 사용자에게 요청](feedback/msvc-request-rule.md) — MSVC 컴파일 필요 시 사용자 Windows PC에 명시 요청
- [배포는 잡 상태로 확인](feedback/feedback-amplify-deploy-verify.md) — git push 성공 ≠ 배포 성공, CI 파이프라인 통과 확인
- [패치노트 작성](feedback/feedback-patch-notes.md) — 의미 있는 작업 후 SemVer 패치노트(드라이 톤)
- [마이페이지 백엔드 없음](feedback/feedback-mypage-no-backend.md) — 클라/Steam 로컬 데이터만 사용
