# TypeScript 코딩 컨벤션

베이스: TypeScript strict 옵션 전부 켜진 상태를 가정. **TS의 태생적 unsoundness와 JS의 함정을 코딩 컨벤션으로 최대한 차단하는 보수적 코드를 작성한다.** ts-executor는 본 문서를 정본으로 참조한다. (JSX/TSX 또는 Next.js/React 작업은 별도 — `next-react.md` 참조.)

## 메타 원칙

- **빌드/타입 검사 조건은 항상 최대 엄격을 가정**하고 코드를 작성한다. 프로젝트의 구체 옵션은 CLAUDE.md에 명시되며, 어떤 경우에도 약화 가정 금지.
- **언어/생태계의 함정을 코드 단에서 차단**: 컴파일러가 못 잡는 부분은 작성 규칙으로.
- **어휘 헬퍼만 표준화** (`invariant`/`assertNever`/`unreachable` 등). **패러다임 헬퍼**(`tryCatch`/`tryCatchAsync`/`mapResult`/`andThenResult`/`combineResults`/`withTimeout`/`traverse` 등)는 **극도로 권장하지 않음** — 강력한 정당화 시에만 사용 (Result는 plain object union이므로 `Result.map` 같은 메서드 표기 금지 — 모두 free-function).
- **인프라 결정은 본 컨벤션의 영역이 아니다**: 라이브러리 선택, 빌드 도구, 모듈 시스템 구체 설정, 린트/포매터 도구, 모노레포 구조, 의존성 정책, CI 게이트 등은 **프로젝트의 CLAUDE.md에서 정의됨**. 본 컨벤션은 그 결정을 가정으로 받아 코드 작성에만 집중.
- **표준 런타임 API 사용을 가정**: `AbortSignal.timeout`, `structuredClone`, `arr.at(-1)`, `Object.hasOwn` 등 비교적 최근 표준 API를 적극 활용. 프로젝트 target이 이를 지원하지 않으면 CLAUDE.md에서 polyfill/대체 정책 명시.
- **JSX/TSX는 본 컨벤션이 다루지 않는다**: JSX/TSX 작성 요청은 `next-react.md` 의 next-react-executor 영역으로 위임.

---

## 1. 타입 시스템 unsoundness 차단

### `any` — 절대 금지
- 코드베이스 내 `any` 0건
- TS 컴파일러 지시문 사용 금지: line 형태(`// @ts-expect-error`, `// @ts-ignore`, `// @ts-nocheck`)와 block 형태(`/* @ts-expect-error */`, `/* @ts-ignore */`, `/* @ts-nocheck */`) 모두
- 외부 라이브러리가 `any`를 강제하면 wrapper에서 즉시 `unknown`으로 변환

### `as` 단언 — 금지 (예외: `as const`)
- 모든 `as` 단언 금지 (`as unknown as T`도 포함)
- **유일한 예외: `as const`** (literal 좁히기, unsoundness 없음)
- 그 외 좁히기는 type guard 함수 또는 schema 검증으로

### type predicate (`x is T`) — 직접 작성 금지
- 함수 본문이 거짓말해도 컴파일러는 믿음 → unsoundness 통로
- **schema 라이브러리가 생성한 predicate만 허용**

### Discriminated Union — 강제
- 모든 union은 통일 tag 필드(`kind` 등) 보유
- `switch`에 `default: assertNever(x)` 의무 (exhaustiveness 컴파일 타임 강제)

### unsound 표준 API 우회
- `JSON.parse`는 직접 사용 금지 (§4 schema 경유 의무)
- `Object.keys/entries/values`, `Array.isArray` 등 표준 라이브러리의 거짓 타입은 신뢰 금지
  - 프로젝트가 `ts-reset` 류를 도입했다면 활용. 미도입 시 wrapper로 `unknown` 반환 강제

### 인덱스 접근 / 사전 구조
- 인덱스 접근 결과는 항상 `T | undefined`로 처리 (가드 의무)
- `{ [k: string]: T }` 인덱스 시그니처 객체 금지
- **`Map<K, V>` 또는 `Record<KnownKeys, T>`만** 사용 (readonly 표기는 §6 표기 통일 참조)

### Branded Type — 위험 경계에 강제
- 외부 ID, URL 문자열, FilePath, SQL/HTML 단편 등 위험 경계 primitive는 brand 의무 (표준 `URL` 객체와 구분)
- 일반 도메인 primitive는 선택

### 함수 오버로드 — 금지
- 오버로드 시그니처는 구현부에서 `any` 강제 → unsound
- 유니온 + 좁히기로 통일

### 클래스 nominal 구분
- 클래스 사용 시 **`#privateField` 1개 이상 강제** (구조적 타이핑 회피, nominal 효과)
- 클래스 자체는 최소 사용 (함수 + 클로저 우선)

### Enum — 금지
- 일반 enum: numeric reverse mapping 함정
- const enum: 빌드 도구 호환성 충돌
- **literal union + branded type만**

### 빈 객체 타입 `{}` — 금지
- `{}`는 `null`/`undefined` 외 거의 모든 값을 허용 (any와 동급으로 위험)
- 의도가 "빈 객체"라면 **`Record<string, never>`**
- 의도가 "임의 객체"라면 **`Record<string, unknown>`**

---

## 2. 에러 처리

### Result 타입 통일
```typescript
type Result<T, E = AppError> =
  | { ok: true; value: T }
  | { ok: false; error: E };
```
- 동기: `Result<T, E>`
- 비동기: `Promise<Result<T, E>>`
- **코드베이스 invariant: Promise는 절대 reject되지 않는다**

### `throw` — invariant violation에만
- `invariant`, `assertNever`, `unreachable` 어휘 헬퍼만 throw 허용
- 그 외 모든 throw 금지 (외부 라이브러리 wrapping은 §5 외부 라이브러리 wrapping 참조)

### try-catch — boundary에서 직접 사용
- 외부 throw 함수 호출 시 boundary에서 직접 try-catch + 즉시 Result 변환 (구체 정책: §5 외부 라이브러리 wrapping)
- 패러다임 헬퍼 도입 금지 (메타 원칙 참조)

### Error 표현
- `AppError` 베이스 클래스 (`Error` 상속) + `kind` discriminator + `cause`
- §1 클래스 `#field` 강제 규칙 적용: `AppError`에 `#brand` 등 private 필드 1개 이상 두어 nominal 구분 보강 (구조적으로 동일한 외부 Error wrapper와 혼동 방지)
- `Error.cause`로 에러 체인 (외부 에러 wrap 시 원본 보존)
- 도메인 컨텍스트(요청 ID, user, 입력 등)는 에러 객체 필드로 (§6에 따라 readonly 기본)

### 비동기
- floating promise 0건. 무시 의도는 `void promise`로 명시
- 외부 IO 함수는 **`AbortSignal` 옵션 매개변수 의무**
- timeout은 표준 **`AbortSignal.timeout(ms)`** 사용 (`withTimeout` 같은 패러다임 헬퍼 회피)

### Promise 합성
- `Promise.all` 사용 (코드베이스 invariant상 모든 Promise는 Result를 반환하므로 reject 없음)
- 패러다임 헬퍼 도입 금지 (메타 원칙 패러다임 헬퍼 목록 참조)

### 어휘 헬퍼 — 표준화 (채택)
```typescript
function invariant(cond: unknown, msg: string): asserts cond;
function assertNever(x: never): never;
function unreachable(msg: string): never;
```
- 역할 분담:
  - `invariant(cond, msg)` — 런타임 condition assert (참이 아니면 throw)
  - `assertNever(x)` — discriminated union exhaustiveness 강제 (`switch` `default`에 사용)
  - `unreachable(msg)` — 도달 불가능한 일반 코드 경로(타입은 narrow됐지만 unreachable임이 자명한 위치). `assertNever`로 표현할 수 없는 unreachable에만 사용
- **호출측 invariant**: `invariant(cond, msg)`의 `cond`는 항상 명시적 boolean 표현이어야 한다 (§3 truthy/falsy 의존 금지). `invariant(x !== undefined, ...)` ✓ / `invariant(x, ...)` ✗
- 헬퍼 시그니처가 `unknown`을 받는 것은 assertion function 타입 제약상 불가피한 구현 사항이며, 호출측의 명시적 비교 의무를 면제하지 않는다

### 패러다임 헬퍼 — 극도로 권장하지 않음
- 메타 원칙의 패러다임 헬퍼 목록(`tryCatch`/`tryCatchAsync`/`mapResult`/`andThenResult`/`combineResults`/`withTimeout`/`traverse` 등) 모두 동일 정책
- 도메인 가치 판단으로 강력히 정당화될 때만 사용

### 로깅 / 종료
- 로깅은 **진입점/경계에서만** (도메인 코드 금지)
- `process.exit`/unhandled rejection handler 등은 main 진입점에서만

---

## 3. JS 함정 차단

- `===`/`!==`만 사용. `==`/`!=` 금지. `== null` 단축 금지 (`x === null || x === undefined`로 분리)
- **truthy/falsy 의존 금지**: 모든 분기는 명시적 비교 (`x === undefined`, `x.length === 0`, `x !== null`)
- 부동소수점 동등성 비교 금지 → `Math.abs(a - b) < EPSILON`
- 큰 정수는 `BigInt` 또는 `string`. 금융·시간은 정수 minor unit (cents, ms)
- `Date` 직접 사용 최소화 — 도메인은 epoch ms 정수 저장, 표시·파싱·연산은 라이브러리 layer
- 메서드를 callback으로 넘길 시 **arrow로 감싸기 우선** (`(x) => obj.method(x)`), 명시적 `bind`는 차선. 콜백을 받는 함수 시그니처는 가능하면 `this: void` 명시 (함수 선언 형식의 일반 정책은 §7 함수 형식 참조)
- 문자열 결합은 템플릿 리터럴만 (`+ 'x' +` 금지). 숫자 변환은 `Number(x)` 명시 (`+x` 단항 금지)
- NaN 체크는 `Number.isNaN(x)`만. 전역 `isNaN` 금지. `Number.isFinite` 사용
- 세미콜론 명시 강제 (ASI 의존 금지)
- `Object.hasOwn(obj, key)` 사용. 사전 구조는 `Map`/`Object.create(null)`
- `JSON.parse`/`stringify`는 schema 경유 강제 (§4 참조)
- switch fallthrough 금지
- `var` 금지, `let`/`const`만
- `with` 금지
- 동적 RegExp 생성 시 escape 헬퍼 의무
- 끝 요소 접근은 `arr.at(-1)`

---

## 4. 런타임 검증 (schema)

### 검증 의무 경계 — 모든 외부 진입점
다음 경계는 **반드시** schema 검증 통과:
- HTTP 요청/응답 (body, query, headers, params)
- Form input
- DB raw query 결과 (프로젝트가 ORM을 신뢰하기로 했다면 ORM 자동 타입은 schema 검증 의무 면제 — 신뢰 정책은 CLAUDE.md에서 결정)
- **환경 변수** (직접 참조 금지, 진입점에서 1회 검증한 객체로 사용)
- 파일/디스크 데이터 (JSON, YAML, CSV)
- IPC / message bus / WebSocket / 외부 큐
- localStorage / sessionStorage / IndexedDB
- URL query params, hash
- 외부 라이브러리 콜백 인자
- `JSON.parse` 결과는 항상 schema parse 의무

### 검증 패턴
- **safeParse 류 (예외 비발생) 사용 강제**. throw 모드 사용 금지
- 결과는 즉시 `Result<T, AppError>` 변환 (boundary 1회)
- 진입점 1회 검증 → 도메인 내부는 검증된 타입 신뢰. 핫 패스 반복 검증 금지

### 타입 단일 source of truth
- **schema → type 추론** 사용
- 별도 interface를 schema와 병행 선언 금지 (drift 위험)

### Schema 배치
- 도메인 모듈 옆에 동거 (응집도). 중앙 집중 금지

### Schema 엄격성
- 객체는 **기본 strict** (추가 필드 거부)
- passthrough/strip은 명시적 의도 + 코멘트 의무 (외부 API forward-compat 등)

### Branded type 통합
- 위험 경계 brand(§1 Branded Type)는 schema 정의에 통합하여, schema 통과 시점에 brand가 부여되도록 한다 (구체 API 형태는 채택 schema 라이브러리 — CLAUDE.md 정의 — 에 따름)

### 비동기 / refine
- schema는 **동기 검증만** (asyncRefine 금지)
- 외부 호출이 필요한 검증(unique 체크 등)은 schema 밖 도메인 로직

### 에러 변환
- schema 에러(path/code/message) → `AppError`로 boundary에서 변환

### 출력 직렬화
- 입력 검증은 의무, 출력은 외부 노출 시 schema parse 권장 (역방향 검증)

### Schema 진화
- breaking change는 명시적 버전 관리 (`SchemaV1`, `SchemaV2` 병존 + migration 함수)

### Schema 테스트
- 모든 schema에 positive(통과) + negative(거부) 단위 테스트
- 외부 API schema는 실제 응답 샘플로 회귀 테스트

---

## 5. 모듈 / 코드 작성

### export
- **named export only** (default export 금지)
- 예외: 프레임워크/도구가 default export를 강제하는 파일에만 허용 (예시는 인프라/프레임워크 의존이며 CLAUDE.md에서 명시). 예외 파일은 명시적 표시 + 사유 코멘트

### import
- **순환 import 금지**
- import 확장자 표기는 프로젝트 환경 정책에 따라 일관 적용 (혼용 금지)
- (import 형식 / 그룹 순서 / `import type` 분리 규칙은 §7 임포트 순서 참조)

### barrel file
- **패키지 경계에만** (외부 노출 표면)
- 내부 모듈은 직접 import (순환·tree-shaking 위험)
- 깊은 barrel chain 금지

### namespace — 금지
- TS `namespace X {}`는 모듈 시스템과 충돌, 레거시. 모듈로 대체

### top-level side effect — 금지
- 모듈 로드 시점의 부수효과(타이머/IO/상태 변경 등) 금지
- 초기화는 명시적 `init()` 함수
- side-effect import는 polyfill 등 명시적 의도 + 코멘트 의무

### dynamic import
- code splitting / 의도적 lazy 시에만
- 일반 의존성은 정적 import

### 외부 라이브러리 wrapping
- throw 기반 외부 라이브러리는 boundary에서 try-catch + Result 변환
- 표준 IO API(`fetch`, `fs/promises` 등)는 wrapper 의무 (`AbortSignal` + Result + schema 검증 통합)
- 의존성 교체 가능성이 있는 라이브러리는 thin wrapper로 격리 (도메인 코드 직접 의존 금지)

### ambient declaration
- **글로벌 ambient 금지**: `declare global { ... }`, 글로벌 namespace 보강 0건. 모든 타입은 명시적 import
- **모듈 ambient는 허용**: 외부 라이브러리 타입 부재 시 `declare module 'lib-name' { ... }` 형태의 모듈 보강 `.d.ts`는 허용. 단, 보강 범위는 해당 라이브러리 모듈 표면에 한정

### JSON 정적 import — 금지
- `resolveJsonModule` / import attribute 사용 안 함
- JSON은 항상 런타임 fs read + schema parse 경유

### 함수 시그니처
- 파라미터 4개 이상이면 객체 파라미터로 전환 (positional 인자 순서 실수 방지)
- boolean 파라미터가 2개 이상이면 즉시 객체화 (호출부에서 의미 식별 강제)

> tree-shaking 친화는 named export + top-level side effect 0 + barrel 최소화 규칙들의 부수효과로 자동 충족된다.

---

## 6. 불변성

### 변수 선언
- **`const` 기본**. `let`은 재할당이 본질적으로 필요한 지역(루프 인덱스, 누산자 등)에서만
- 모듈 최상위 mutable 상태(`let foo = ...`) 금지

### 객체/타입의 readonly
- **모든 객체 필드는 `readonly` 기본**. 가변이 의도일 때만 명시적으로 제거
- 외부 노출(export) 함수의 인자/반환 타입은 readonly **의무**
- 클래스 필드도 readonly 기본. 상태 변경은 새 인스턴스 반환으로 표현

### 표기 통일
- **배열**: `readonly T[]` (단축형). `ReadonlyArray<T>` 혼용 금지
- **Map/Set**: `ReadonlyMap<K, V>` / `ReadonlySet<T>`
- **튜플**: 정의 시 `as const`, 시그니처에 등장할 때는 `readonly [A, B, C]`

### 리터럴 / 상수
- 상수성 객체/배열 리터럴은 **`as const` 의무**
- readonly → mutable로의 `as` 캐스트 금지 (§1 `as` 금지의 부분 집합)

### 변형 작업
- 배열 변형은 immutable 메서드 우선: `toSorted` / `toReversed` / `with` / `toSpliced`. `sort`/`reverse`/`splice` 직접 호출 금지
- Map/Set 변경은 새 인스턴스로(`new Map([...m, [k, v]])`)
- 깊은 복사는 **`structuredClone`**

### Freeze / 순수성
- `Object.freeze`는 진입점/공유 상태에만 (모든 객체에 강제하지 않음 — 비용)
- 도메인 로직은 순수 함수 우선. 입력 인자 mutation 금지

### 동시성 안전성
- async 클로저가 외부 변수를 mutate하는 패턴 금지 (race 위험)
- `RegExp`의 `/g`/`/y` `lastIndex` 의존 금지 (글로벌 mutable 상태)

---

## 7. 네이밍 / 포매팅

> 인프라(prettier/eslint 규칙값 자체)는 CLAUDE.md 영역. 본 절은 **작성자가 결정해야 하는** 코드 컨벤션만 다룬다.

### 식별자
- 변수 / 함수 / 메서드 / 속성: `camelCase`
- 타입 / 인터페이스 / 클래스 / 타입 별칭: `PascalCase`
- 상수(`as const` 리터럴, freeze된 모듈 최상위 값): `SCREAMING_SNAKE_CASE`
  - 단, 객체 리터럴 내부 필드명은 `camelCase` (외부 API 스키마와 1:1 매칭일 때만 예외)
- 제네릭 타입 파라미터: `T`, `U`, `K`, `V` 단문자 우선 (단문자는 대문자만). 의미 필요 시 `T` prefix + PascalCase (`TKey`, `TItem`). suffix `T` 금지, 소문자 시작 금지 (`tKey` 등 금지)
- private 클래스 필드: `#field` (§1 클래스 nominal 구분 참조). underscore prefix(`_field`)로 private을 표기하는 관례 금지 — `#`만 허용
- unused 변수: `_` 또는 `_name`

### 불리언 / 함수
- 불리언 변수/속성: `is/has/can/should/will/did` 중 하나로 시작. `isNotXxx` 등 부정형 금지
- 함수: 동사+목적어. 부수효과는 명령형(`saveUser`), 순수 변환은 `to`/`from`(`toIso`, `fromBson`), 술어는 불리언 명명 규칙
- async 함수에 `Async` suffix 금지 (반환 타입이 `Promise<T>`로 자명)

### 약어
- 약어 길이 무관 PascalCase 단어처럼 취급: `userId`, `UserId`, `parseUrl`, `HttpClient`. `HTTPClient`/`UserID` 금지

### 타입 선언
- 객체 형태는 **`type` 우선**. `interface`는 (1) declaration merging 필요 또는 (2) ambient 라이브러리 확장 시에만
- union / intersection / 조건 / 유틸리티 타입은 항상 `type`
- interface / type literal 멤버 구분자 모두 **`;` 통일** (콤마/줄바꿈 단독 금지)

### 함수 형식
- 모듈 최상위 함수: `function` 선언 우선 (호이스팅, 안정 스택 트레이스)
- 콜백 / 지역 클로저 / 인자로 넘기는 함수: arrow
- 클래스 메서드: 일반 메서드 문법. 필드+arrow는 `this` 바인딩이 정말 필요한 경우(예: 이벤트 핸들러)에만
- arrow에서 객체 리터럴 반환 시 `({ ... })`로 묶어 표현식 형태 유지 (block body로 풀지 말 것)

### 파일 / 디렉토리
- 파일명: **`kebab-case.ts`** 통일 (`UserService.ts` 같은 PascalCase 금지 — OS case sensitivity 차이로 import 깨짐 방지)
- 디렉토리: `kebab-case`
- 테스트 파일 suffix(`.test.ts` vs `.spec.ts`)는 프로젝트당 하나로 통일 (선택은 CLAUDE.md). 한 프로젝트 내 혼용 금지
- 타입-only 파일에 별도 suffix 강제 없음 (`import type`로 충분)

### 임포트 순서
- 그룹: ① `node:` 빌트인 → ② 외부 패키지 → ③ 내부 alias → ④ 상대 경로. 그룹 사이 빈 줄 1, 그룹 내 알파벳 순
- `import type`은 별도 줄. 같은 모듈에서 type/value를 함께 가져오면 두 줄로 분리 (또는 인라인 `import { type T, fn }`)

### 주석 — 최소화 **강력 권장**
- **주석은 기본적으로 쓰지 않는다.** 식별자/타입/구조로 의도를 표현하지 못할 때만 작성
- 작성한다면 **WHY만**: 비자명한 제약, 미묘한 invariant, 특정 버그 회피, 외부 환경 차이 등
- WHAT을 설명하는 주석(코드를 자연어로 풀어쓴 것) 금지
- 일반 주석은 `//` line comment. 블록 주석 `/* */`은 다음 두 경우 외 전면 금지:
  - TSDoc `/** */` (외부 API export 대상 한정 — 시그니처 풀어쓰기 식이면 작성 안 함)
  - 외부 도구가 인라인 hint를 블록 주석 형태로 강제하는 경우 (강력한 정당화 시에만)
- TS 컴파일러 지시문(`// @ts-*` / `/* @ts-* */`) 자체는 §1에서 금지되므로 블록 주석 예외 사유로 인용할 수 없다
- 파일 상단 박스 주석/저작권 헤더 금지 (필요하면 빌드 단계에서 주입)

### 기타
- discriminated union의 `kind`/`type` 태그값 표기는 프로젝트당 하나(`kebab-case` 또는 `snake_case`)로 통일. 한 코드베이스 내 혼용 금지

---

## 자체 리뷰 체크리스트

### 타입 시스템
- [ ] `any` 0건, `as` 0건 (단 `as const` 제외), `// @ts-*` / `/* @ts-* */` 코멘트 0건
- [ ] type predicate은 schema 라이브러리 생성분만 (직접 작성 0건)
- [ ] 모든 union은 discriminated tag, switch에 `assertNever`
- [ ] `Map`/`Record<KnownKeys, T>` 사용. index signature 객체 0건
- [ ] `Object.keys/entries/values`, `Array.isArray` 거짓 타입 직접 신뢰 0건 (ts-reset 또는 wrapper 경유)
- [ ] enum 사용 0건 (literal union + brand로 대체)
- [ ] 함수 오버로드 0건
- [ ] 클래스 사용 시 `#field` 존재
- [ ] 위험 경계 primitive에 brand 적용
- [ ] 인덱스 접근에 가드 존재
- [ ] 빈 객체 타입 `{}` 0건 (`Record<string, never>` 또는 `Record<string, unknown>`로 대체)

### 에러 처리
- [ ] Result 타입 일관 적용. Promise reject 사용 0건
- [ ] `throw`는 invariant/assertNever/unreachable 헬퍼에만
- [ ] try-catch는 boundary에서 직접 사용 (즉시 Result 변환)
- [ ] 패러다임 헬퍼(`tryCatch`/`tryCatchAsync`/`mapResult`/`andThenResult`/`combineResults`/`withTimeout`/`traverse` 등) 도입 0건. `Result.map` 메서드 표기 0건 (free-function만)
- [ ] 어휘 헬퍼 시그니처 정의 존재(`invariant`/`assertNever`/`unreachable`), 호출측 `invariant`는 명시적 boolean 표현만 전달
- [ ] floating promise 0건 (또는 `void promise`로 명시)
- [ ] 외부 IO 함수에 `AbortSignal` 매개변수 존재
- [ ] timeout은 `AbortSignal.timeout`
- [ ] `AppError` 상속 + `kind` + `cause` + `#field` (nominal 보강)
- [ ] 로깅은 진입점/경계에서만, `process.exit`/unhandled rejection handler는 main 진입점에서만

### JS 함정
- [ ] `==`/`!=`, `==null` 단축 0건
- [ ] truthy/falsy 분기 0건 (모두 명시적 비교)
- [ ] 부동소수점 직접 동등 비교 0건 (EPSILON 비교)
- [ ] 큰 정수는 `BigInt` 또는 `string`, 금융·시간은 정수 minor unit
- [ ] `Date` 직접 연산 없음 (epoch ms 또는 라이브러리)
- [ ] `Number.isNaN`/`Number.isFinite` 사용
- [ ] `Object.hasOwn` 사용
- [ ] `arr.at(-1)` 사용
- [ ] `var` 0건, `with` 0건, switch fallthrough 0건
- [ ] 문자열 결합은 템플릿 리터럴만, 숫자 변환은 `Number(x)` (`+x` 단항 0건)
- [ ] 동적 RegExp는 escape 헬퍼 경유
- [ ] 세미콜론 명시 (ASI 의존 0건)

### 런타임 검증
- [ ] 모든 외부 진입점이 schema 검증을 통과
- [ ] safeParse 류 사용, throw 모드 0건
- [ ] schema → type 추론. 병행 interface 0건
- [ ] schema는 도메인 모듈에 동거(중앙 집중 0건)
- [ ] schema 객체는 strict 기본 (passthrough/strip은 명시적 의도 + 코멘트)
- [ ] 위험 경계 brand는 schema 정의에 통합
- [ ] asyncRefine 0건
- [ ] 환경 변수 직접 참조 0건 (검증된 env 객체만 사용)
- [ ] `JSON.parse` 직접 사용 0건 (schema 경유)
- [ ] schema 에러는 boundary에서 `AppError`로 변환
- [ ] 외부 노출 출력은 schema parse로 역방향 검증 권장
- [ ] schema breaking change는 명시적 버전(`SchemaV1`/`SchemaV2`) + migration 함수
- [ ] 모든 schema에 positive/negative 단위 테스트, 외부 API schema는 응답 샘플 회귀 테스트

### 모듈 / 코드 작성
- [ ] named export only (정당한 default export 예외만 허용)
- [ ] type-only는 `import type`/`export type`
- [ ] import 순서 준수, 순환 import 0건
- [ ] import 확장자 표기 일관(혼용 0건)
- [ ] barrel file은 패키지 경계에만
- [ ] namespace 0건, top-level side effect 0건
- [ ] dynamic import는 code splitting/lazy 시에만 (일반 의존성은 정적 import)
- [ ] side-effect import(polyfill 등)는 명시적 의도 + 코멘트
- [ ] JSON 정적 import 0건
- [ ] `declare global` 0건 (모듈 ambient `declare module 'lib'`는 라이브러리 표면 한정 허용)
- [ ] 외부 라이브러리는 thin wrapper로 격리
- [ ] 함수 파라미터 4개 이상은 객체화, boolean 2개 이상은 즉시 객체화

### 불변성
- [ ] `const` 기본, `let`은 본질적 재할당 지역에만
- [ ] 모듈 최상위 mutable 상태 0건
- [ ] 객체 필드 readonly 기본, export 함수의 인자/반환은 readonly 의무
- [ ] 클래스 필드 readonly 기본, 상태 변경은 새 인스턴스 반환
- [ ] 배열 표기 `readonly T[]`로 통일 (`ReadonlyArray<T>` 혼용 0건)
- [ ] Map/Set은 `ReadonlyMap`/`ReadonlySet`
- [ ] 튜플은 정의 시 `as const`, 시그니처 등장 시 `readonly [A, B, C]`
- [ ] 상수성 리터럴에 `as const`
- [ ] 배열 변형은 `toSorted`/`toReversed`/`with`/`toSpliced` 우선 (`sort`/`reverse`/`splice` 직접 호출 0건)
- [ ] Map/Set 변경은 새 인스턴스
- [ ] 깊은 복사는 `structuredClone`
- [ ] `Object.freeze`는 진입점/공유 상태에만 적용 (전역 강제 0건)
- [ ] 도메인 로직은 순수 함수 우선, 입력 인자 mutation 0건
- [ ] `RegExp` `/g`/`/y` `lastIndex` 의존 0건
- [ ] async 클로저의 외부 변수 mutation 0건

### 네이밍 / 포매팅
- [ ] camelCase / PascalCase / SCREAMING_SNAKE_CASE 규칙 일관
- [ ] 제네릭 타입 파라미터는 단문자 대문자(`T`/`U`/`K`/`V`) 또는 `T` prefix + PascalCase(`TKey`). suffix `T`·소문자 시작 0건
- [ ] private 클래스 필드 표기는 `#field`만. underscore prefix(`_field`)로 private 관례 표기 0건
- [ ] 약어 PascalCase 단어 취급 (`UserId`, `parseUrl` — `UserID`/`HTTPClient` 0건)
- [ ] 불리언은 `is/has/can/should/will/did` prefix (부정형 `isNotXxx` 0건)
- [ ] async 함수에 `Async` suffix 0건
- [ ] 객체 형태 타입은 `type` 우선, interface는 declaration merging/ambient 확장 시에만
- [ ] interface/type literal 멤버 구분자 `;` 통일
- [ ] 모듈 최상위 함수는 `function` 선언, 콜백/클로저는 arrow
- [ ] 클래스 메서드는 일반 메서드 문법 (필드+arrow는 this 바인딩 필요 시에만)
- [ ] arrow의 객체 리터럴 반환은 `({ ... })` 표현식 형태 유지
- [ ] 파일명/디렉토리명 kebab-case
- [ ] import 그룹 순서 + 그룹 간 빈 줄, `import type` 별도 줄
- [ ] discriminated union 태그값 표기(`kebab-case`/`snake_case`) 프로젝트 단일 통일

### 주석
- [ ] WHAT 설명 주석 0건
- [ ] 작성된 주석은 모두 WHY (비자명 제약 / invariant / 버그 회피 / 환경 차이)
- [ ] 블록 주석 `/* */` 0건 (외부 도구 인라인 hint 정당화 시 예외만)
- [ ] 파일 상단 박스/저작권 헤더 0건
- [ ] TSDoc `/** */`은 외부 export 한정, 시그니처 풀어쓰기 0건
