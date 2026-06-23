---
name: feedback-patch-notes
description: MM/mm-game-client 의미 있는 작업이 끝나면 SemVer 기반 패치노트를 docs/patch-notes/에 반드시 작성한다 (드라이 톤·외부 효과 중심).
type: feedback
originSessionId: 55c34d65-6a7e-420e-ab24-e26ed70185bb
---
작업 완료 후 **반드시 패치노트 작성**.

**Why:** 작가에게 외부 공지용 + 변경 이력 추적. 라운드 단위 변경이 누적되면 *무엇이 언제 바뀌었는지* 사라지기 쉬움.

**How to apply:**
- 의미 있는 작업(기능·UI·schema·BREAKING) 완료 시점에 작성. 핫픽스(1-2줄)는 생략 가능.
- 파일명: `docs/patch-notes/YYYY-MM-DD-v<X.Y.Z>-<topic>.md` (MM) / mm-game-client 별 리포는 자체 `docs/patch-notes/`
- **SemVer 2.0.0**: MAJOR(BREAKING)·MINOR(신규 기능)·PATCH(버그·디자인)
- 톤: **드라이**, 사용자/작가에게 보이는 효과만. 인사·메타·미래 다짐 금지.
- 사용자 이전 명시: "패치노트 톤은 더 드라이하게", "현재 변경된 것들만 적어".
