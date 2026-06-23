---
name: feedback-helpers
description: 헬퍼·유틸 클래스는 최적화에 직접 기여할 때만 만들 것. 단순 코드 중복 제거 목적 금지.
type: feedback
originSessionId: 55c34d65-6a7e-420e-ab24-e26ed70185bb
---
헬퍼·유틸 클래스·base class를 만들 때는 그게 **최적화에 직접 도움을 주는 경우만** 허용. 단순 코드 중복 제거·가독성·재사용 편의 목적은 금지.

**허용 예시:**
- ShaderMaterial 캐싱(GPU shader 재컴파일 회피) — static field로 cache
- 이미지 디스크 캐시(disk I/O dedup) — 명확한 성능 이득

**금지 예시:**
- 같은 모양 StyleBoxFlat을 매번 새로 만든다고 SharedStyleBoxes 헬퍼 생성 — GC 부담 미미하고 캐싱 키 만들 복잡도가 이득 초과
- BuildContent 일관화를 위한 abstract base class — 패턴은 코드에 직접 적용
- 비슷한 호출 묶음을 한 메서드로 — 호출처 코드가 명확하면 그대로

**Why:** 헬퍼는 코드 표면적을 늘리고 진단·수정 시 호출 chain을 늘림. 명확한 성능 이득이 없으면 호출처에서 직접 처리하는 게 단순.

**How to apply:** sub-project 설계 시 각 헬퍼 후보에 대해 "이게 GPU/CPU/메모리/I/O 측정 가능한 이득을 주는가?" 자문. NO면 헬퍼 X, 패턴으로 처리.
