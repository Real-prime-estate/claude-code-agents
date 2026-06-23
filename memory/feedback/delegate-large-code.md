---
name: delegate-large-code
description: "cpp-procgen에서 큰 코드는 cpp-executor에 위임, 작은 것은 직접 작성"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 443f695c-a222-42cf-875c-d3380990be6a
---

cpp-procgen 작업 시 **큰 코드 작성은 전부 `cpp-executor` 로컬 에이전트에 위임**(Agent 툴, subagent_type=cpp-executor), **작은 것(버그수정/CMake·엄브렐러 배선/테스트 수정/글루/짧은 함수/C 예제)은 Claude가 직접** 작성.

**Why:** 작업 효율성(2026-06-23 지시).
**How to apply:** 위임 시 프로젝트 컨벤션을 반드시 브리핑(의존성0, 엄격 플래그·-ffp-contract=off 결정론, rng::Engine concept, dmu_ 접두, 헤더온리+C ABI, libc++ 엄격성, 골든 결정론, 명시적 정수 캐스트). 통합·골든 캡처·전 프리셋 검증(gcc/clang/clang-asan/Docker)·커밋은 Claude가 직접. CLAUDE.md에도 박혀 있음.

[[demiurge-project]] [[validation-strategy]]
