---
name: always-commit-after-task
description: cpp-procgen 작업 완료 시마다 크기 무관 무조건 먼저 커밋하라는 지시
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 443f695c-a222-42cf-875c-d3380990be6a
---

사용자 지시(2026-06-23): cpp-procgen 작업이 끝나면 **크든 작든 무조건 먼저 커밋**한다(리포트/다음 작업보다 커밋이 우선).

**Why:** 모든 진행을 커밋 체크포인트로 남기고 싶어함.
**How to apply:** 한 단위 작업(모듈 추가/수정/문서)을 끝낼 때마다 즉시 `git commit`. conventional commits 스타일 메시지. 개인 리포라 기본 브랜치 `main`에 직접 커밋. 커밋 메시지 끝에 Co-Authored-By 라인 포함.

[[demiurge-project]]
