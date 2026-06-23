---
name: feedback-mypage-no-backend
description: mm-game-client의 마이페이지(MyPageScreen)는 백엔드 의존 없음 — 모든 데이터는 클라/Steam 로컬에서
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 55c34d65-6a7e-420e-ab24-e26ed70185bb
---

mm-game-client의 마이페이지(MyPageScreen)는 백엔드 API 호출을 두지 않는다.

**Why:** 2026-05-20 사용자 결정. 출시 인증은 Steam OIDC 단독이며, 마이페이지의 사용자 정보·아바타·플레이 기록 등은 Steam persona·로컬 cache·Steam Cloud Save에서 직접 가져온다. 별도 `/api/users/me` 같은 endpoint를 만들지 않는다.

**How to apply:**
- MyPageScreen·EditProfileModal 등 마이페이지 영역 코드에 `ApiAutoload` 참조 도입 금지.
- 서버에 마이페이지 전용 endpoint 신규 추가 금지 (admin-users는 어드민 전용이라 무관).
- 닉네임·아바타·플레이 기록·업적은 Steam SDK + Cloud Save에서 hydrate.
- 이 정책은 게임 클라(mm-game-client)에만 해당. CMS([[project-overview]]) 작가용 페이지는 별도 — 백엔드 API 정상 사용.
