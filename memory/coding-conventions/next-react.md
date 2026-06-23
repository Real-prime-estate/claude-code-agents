# Next.js / React / TSX 코딩 컨벤션

베이스: Next.js App Router + React + TSX + strict TypeScript + ESLint. **`typescript.md` 의 보수적 안전성 철학을 유지하되, TSX와 Next App Router의 현실을 반영한다.** next-react-executor는 본 문서를 정본으로 참조하며, 일반 TS 규칙(타입 시스템 unsoundness, 에러 처리, JS 함정, schema 검증, 모듈, 불변성, 네이밍/포매팅)은 `typescript.md`를 함께 read 한다.

## 1. ts-executor와의 경계

- TSX, React component, Next page/layout, UI state, browser API 코드는 **next-react-executor**가 담당한다.
- 순수 TypeScript 라이브러리, SDK, 런타임 독립 도메인 코드는 **ts-executor**가 담당한다.
- 두 영역이 섞이면 UI boundary는 next-react-executor, core logic은 ts-executor 규칙을 적용한다.

## 2. 프레임워크 예외 정책

`typescript.md`의 일부 엄격 규칙은 Next/React 생태계 현실에 맞춰 다음과 같이 완화된다.

1. Next App Router가 요구하는 `page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, route 파일의 default export는 허용한다.
2. 기존 코드베이스가 default-export component 관례이면 컴포넌트 default export도 허용한다. 신규 shared library만 named export를 우선한다.
3. TSX는 본 컨벤션의 핵심 영역이다. JSX/TSX 미커버로 보고하지 않는다.
4. React props와 공개 객체 shape에는 `interface`를 허용한다. union, mapped, conditional type은 `type`을 우선한다.
5. `as` 단언은 DOM event, framework params, third-party boundary, 검증 완료 데이터 변환에서만 최소 범위로 허용한다.
6. Promise rejection은 Next/React 생태계에서 정상적인 boundary 동작이다. UI event/server action/API client에서 잡아 UI state 또는 typed error로 변환한다.
7. Result 전면 강제는 하지 않는다. API/client boundary나 도메인 로직에서 가치가 있을 때만 사용한다.

## 3. 엄격 안전 규칙 (TSX 영역에서 강제)

`typescript.md`의 규칙들 중 TSX/React 영역에서도 그대로 유지되는 것들.

1. `any` 신규 사용 금지. 불가피한 third-party 구멍은 adapter에 격리하고 즉시 `unknown` 또는 검증 타입으로 변환한다.
2. non-null assertion `!` 금지. guard, early return, fallback UI를 사용한다.
3. `eslint-disable` 신규 사용 금지. 필요하면 구조를 바꿔 규칙을 만족한다.
4. 외부 API 응답, localStorage/sessionStorage, URL param, form input, env는 신뢰하지 않는다. 가능한 schema/guard로 좁힌다.
5. `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `strict` 기준을 약화하지 않는다.
6. indexed access는 항상 `undefined` 가능성을 처리한다.
7. 복잡한 UI state는 discriminated union으로 표현한다.
8. 입력 props/state mutation 금지. immutable update를 사용한다.

## 4. React / Next 규칙

1. Rules of Hooks 준수. Hook은 조건문/반복문/중첩 함수에서 호출하지 않는다.
2. `react-hooks/exhaustive-deps`는 error로 본다. suppress하지 말고 `useMemo`, `useCallback`, reducer, ref, effect 분리로 해결한다.
3. `"use client"`는 hooks, browser API, interactivity가 필요한 최소 파일에만 둔다.
4. Server component에서는 browser API, stateful hook, event handler를 사용하지 않는다.
5. loading, empty, error, success 상태를 명시적으로 처리한다.
6. form은 controlled input을 우선하되 단순 uncontrolled가 더 안전하면 허용한다.
7. 접근성: label, button semantics, keyboard interaction, aria 속성을 확인한다.
8. 기존 디자인 시스템/CSS 패턴을 보존한다. 디자인 요청이 아니면 시각 언어를 새로 만들지 않는다.

## 5. 작업 시 확인 순서

1. `package.json`, `tsconfig`, `eslint.config`, Next 버전, app router 구조를 확인한다.
2. 대상 파일이 server/client/shared/API client 중 어디인지 분류한다.
3. 기존 import/export/style 패턴을 맞춘다.
4. 코드 작성/수정 후 자체 리뷰한다.
5. 가능하면 `npm run typecheck`, `npm run lint`, `npm run build` 또는 프로젝트 `ci`를 실행한다.

## 자체 리뷰 체크리스트

`typescript.md` 의 체크리스트와 함께 다음 항목을 추가 확인한다.

- [ ] `any`, non-null assertion, `eslint-disable` 신규 0건
- [ ] Hook dependency와 Rules of Hooks 준수
- [ ] client/server component boundary 적절
- [ ] 외부 데이터는 검증/guard 후 사용
- [ ] loading/empty/error/success 상태 처리
- [ ] props/state mutation 없음
- [ ] 접근성 기본 요소 확인 (label, button semantics, keyboard, aria)
- [ ] App Router 파일 규칙 (`page`/`layout`/`loading`/`error`/`route`) 준수
- [ ] `"use client"` 가 hooks/browser API/interactivity가 필요한 최소 파일에만
- [ ] Server component에서 browser API/stateful hook/event handler 미사용
- [ ] typecheck/lint/build 또는 가장 가까운 검증 실행
