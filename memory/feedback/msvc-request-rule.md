---
name: msvc-request-rule
description: MSVC 컴파일이 필요할 때마다 사용자 Windows PC에 컴파일을 요청하라는 규칙
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 443f695c-a222-42cf-875c-d3380990be6a
---

cpp-procgen에서 **MSVC 컴파일/검증이 필요할 때마다, 사용자에게 "당신의 Windows PC에서 컴파일해 달라"고 명시적으로 요청**하고 결과를 받아 대응한다.

**Why:** Claude는 macOS 환경이라 MSVC를 직접 못 돌림. 사용자는 실물 Windows PC(x86_64, Ryzen 5 9600X)와 Ubuntu 듀얼부팅을 보유 → 실기기 검증 가능.
**How to apply:** MSVC 관련 코드 변경/검증 시 임의로 우회·생략하지 말고 사용자에게 요청. 평소엔 컴파일 클린을 상시 유지(Docker Linux + macOS gcc/clang)하되, MSVC 첫 빌드 시 코드 수정이 생길 수 있음을 염두. CLAUDE.md에 RULE로 박혀 있음.

[[validation-strategy]] [[demiurge-project]]
