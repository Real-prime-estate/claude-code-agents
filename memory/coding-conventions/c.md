# C 코딩 컨벤션

베이스: **BSD KNF (style(9)) 계보** + C11 표준. c-executor 에이전트는 코드 작성과
자체 리뷰 시 본 문서를 정본으로 참조한다.

계보 선언(2026-07-10 개정): 본 컨벤션은 벨 연구소 Research UNIX → 4BSD →
FreeBSD/OpenBSD style(9)로 이어지는 KNF 전통을 기반으로 하고, 그 위에
**하우스 층**(SDK/라이브러리 위생 — §2 접두사, §3 opaque, §8 오류 규약)을
얹는다. 하우스 층은 계보 밖 의도적 추가이며 각 절에 [하우스] 표기한다.
구판(Linux kernel 베이스)에서의 전환이므로, 기존 코드베이스는 재정형 시
반드시 동작 불변 검증(테스트·golden)과 함께 간다.

## 1. 표준과 빌드 가정

- C11 표준(`-std=c11`)을 가정한다. C99 이전 기능으로의 약화 금지.
- 컴파일러 경고 최대 가정: `-Wall -Wextra -Wpedantic`. `-Werror` 여부는 프로젝트 결정.
- 폭(width)이 의미 있는 자료형만 `<stdint.h>` (§10). 그 외엔 기본 정수형(`int`, `size_t`, `ssize_t`).
- 호스트 환경은 POSIX를 기본 가정한다. 비POSIX 의존이 필요하면 그 사실을 명시한다.
- 빌드 도구, 의존성 정책, 정적 분석 옵션, CI 게이트는 본 문서의 영역이 아니다. 프로젝트의 CLAUDE.md에서 정의된다.

## 2. 네이밍

| 종류 | 형식 | 예 |
|---|---|---|
| 변수, 함수 | snake_case | `hash_map_init`, `pixel_count` |
| 매크로, 상수 | UPPER_SNAKE_CASE | `MAX_BUF_SIZE`, `HASH_MAP_DEFAULT_CAP` |
| Opaque 타입 | snake_case + `_t` | `hash_map_t`, `image_t` |
| 일반 struct/union | tag만, typedef 없음 | `struct point`, `union value` |
| 함수 포인터 typedef | `_fn` 또는 `_cb` | `compare_fn`, `on_done_cb` |
| 열거형 | UPPER_SNAKE 멤버 | `enum log_level { LOG_INFO, LOG_WARN }` |

[하우스] 공개 심볼(헤더에 노출되는 함수, 타입, 매크로)은 **모듈명 접두사**를
갖는다. 모듈이 `hash_map`이면 `hash_map_init`, `hash_map_t`,
`HASH_MAP_DEFAULT_CAP` 형식이다. KNF 원전은 단일 시스템 코드베이스라 이
규칙이 없으나, 우리는 남의 코드에 링크되는 라이브러리를 만들므로 심볼 위생이
필수다.

내부 정적 심볼은 접두사를 짧게 줄여도 된다(예: 모듈 안에서만 쓰는 헬퍼를 `hm_rehash`로). 한 파일 내에서 일관성을 유지한다.

[하우스] `_t` 접미사는 opaque typedef에만 쓴다. BSD 시스템 헤더는 `_t`를 널리
쓰지만 POSIX 예약 패턴이므로 응용 라이브러리인 우리는 opaque 표시로 한정한다.

## 3. 타입과 typedef

원칙: **opaque만 typedef. 가시 layout은 `struct tag` 직접 사용.**

```c
// opaque: 내부 layout 비공개
typedef struct hash_map hash_map_t;
hash_map_t *hash_map_create(size_t cap);

// 가시 layout: typedef 없음
struct point { int x; int y; };
void point_translate(struct point *p, int dx, int dy);
```

`struct` 키워드의 유무가 가시성을 알린다(가시 layout이냐 opaque이냐). BSD·kernel 양 전통 모두와 정합한다.

함수 포인터는 typedef를 허용하되 접미사를 강제한다.

```c
typedef int (*compare_fn)(const void *a, const void *b);
typedef void (*on_done_cb)(void *ctx, int rc);
```

## 4. 포인터, 비교, 접두사

포인터 `*`는 변수 쪽에 붙인다. `int *p`, `char **argv`. `int* p` 금지. 한 줄에 여러 포인터 변수 선언은 의미가 모호해지므로 한 줄당 한 변수 선언을 권고한다.

**명시 비교(KNF)**: 포인터는 `== NULL` / `!= NULL`, 정수는 `== 0` / `!= 0`으로
명시 비교한다. `!`는 진짜 bool에만 쓴다.

```c
if (map == NULL || key == NULL)
	return (RC_EINVAL);
```

[하우스] 스코프 접두사:

| 접두사 | 의미 | 예 |
|---|---|---|
| `g_` | 파일 외부에서 보이는 전역 | `extern int g_log_level;` |
| `s_` | 파일 내부 정적 | `static int s_cache_hits;` |
| `out_` | 출력 파라미터 | `int parse(const char *s, int *out_value);` |

전역과 정적 변수는 가능한 줄인다. 출력 파라미터는 반환값으로 줄 수 없을 때만 사용한다(예: 다중 출력, 또는 반환값이 이미 상태 코드인 경우).

## 5. 들여쓰기, 줄, 중괄호, 선언 (KNF)

- 탭 들여쓰기, 탭 폭 8. **연속행(줄바꿈된 식의 이어지는 줄)은 4칸 공백** 추가 들여쓰기.
- K&R 중괄호: 함수 정의는 여는 중괄호를 다음 줄 0열에, 그 외(if/for/while/switch)는 같은 줄에. `} else {` 형식.
- 80열 권고, 100열 상한. 긴 식은 인자 단위로 줄바꿈.
- 단일 문 if는 KNF 전통대로 중괄호 생략을 허용하되, dangling 위험(else 결합·후속 수정)이 있는 자리는 중괄호를 쓴다. 한 함수 안에서 스타일을 섞지 않는다.
- **선언은 블록 선두에 모은다.** 정렬 순서: 크기 큰 것부터, 같은 크기는 알파벳.
  단순 리터럴 초기화는 선언에서 허용하고, 계산이 필요한 초기화는 본문 첫
  문장으로 내린다. [하우스 완화 — style(9) 원전은 선언 초기화에 더 보수적]
- 무한 루프는 `for (;;)`.

```c
int
hash_map_get(struct hash_map *map, const char *key, void **out_value)
{
	struct hm_bucket *bkt;
	size_t idx;
	int rc = 0;

	if (map == NULL || key == NULL)
		return (RC_EINVAL);
	// ...
}
```

## 6. 함수 정의와 return (KNF)

함수 정의는 **저장 클래스·반환형을 한 줄에, 함수 이름을 다음 줄 0열에** 둔다
(V7 UNIX 이래의 KNF 형식 — grep `^name`으로 정의를 찾을 수 있다).

```c
static int
hash_map_grow(struct hash_map *map)
{
	// ...
}
```

선언(헤더)에서는 한 줄 형식을 사용한다.

```c
int hash_map_grow(struct hash_map *map);
```

**return 값은 괄호로 감싼다**: `return (0);`, `return (rc);`. 값 없는
return은 `return;`. — KNF의 지문이며 본 컨벤션의 정본 형식.

함수는 한 가지만 하도록 작성한다. 줄 수로 강제 분할하는 룰은 두지 않는다. 분리할 가치가 없는 함수를 억지로 쪼개면 호출 경로가 더 어려워진다.

## 7. 주석 스타일 [하우스 — KNF 이탈]

- **`//` 전용.** `/* */` 금지(박스 헤더·블록 주석 포함). KNF의 `/* */` 전통을
  의도적으로 대체하는 하우스 이탈이다(2026-07-10 사용자 결정).
- **극단 최소화 — 코드로 말한다 규칙을 극도로 엄격히 적용한다.** 남길 자격이
  있는 주석은 오직 세 종류:
  1. **스펙 앵커**: 이 코드가 어느 규범 조항의 구현인지 (예: `// v2.3 §1`)
  2. **코드로 표현 불가능한 불변식·전제** (예: `// 호출 전제: tot <= 2^16`)
  3. **비자명한 왜(why)** — 이렇게 안 하면 무엇이 깨지는지
- 그 외 전부 금지: 무엇(what)·어떻게(how)를 설명하는 주석, 섹션 배너,
  자명한 부연, 이력·저자 주석. 주석이 필요해 보이면 먼저 이름과 구조를
  고칠 수 있는지 본다 — 주석은 코드 개선 실패의 마지막 수단이다.
- 공개 API 헤더 주석도 같은 기준: 계약(전제·소유권·오류)만, 산문 금지.

## 8. 리소스 관리: `goto cleanup` 패턴

`malloc`, `fopen`, `pthread_create` 같이 짝이 있는 리소스를 다루는 함수는 단일 cleanup 출구로 정리한다. 중첩 if 회피와 누수 차단이 핵심이다. (BSD·kernel 공통 전통 — 레이블명은 `cleanup` 통일. [하우스])

```c
int
load_config(const char *path, struct config **out_cfg)
{
	struct config *cfg = NULL;
	FILE *fp = NULL;
	char *buf = NULL;
	int rc = 0;

	fp = fopen(path, "rb");
	if (fp == NULL) {
		rc = -errno;
		goto cleanup;
	}

	buf = malloc(MAX_CONFIG_SIZE);
	if (buf == NULL) {
		rc = -ENOMEM;
		goto cleanup;
	}

	cfg = calloc(1, sizeof(*cfg));
	if (cfg == NULL) {
		rc = -ENOMEM;
		goto cleanup;
	}

	// ... 파싱 ...

	*out_cfg = cfg;
	cfg = NULL;	// 소유권 이전

cleanup:
	free(cfg);
	free(buf);
	if (fp != NULL)
		fclose(fp);
	return (rc);
}
```

규칙:

- 리소스 변수는 함수 진입 직후 NULL 초기화(§5 선언 정렬과 함께).
- `goto cleanup` 단일 레이블. 다중 레이블이 필요하면 함수 분해를 검토한다.
- 소유권이 이전된 자원은 NULL 대입으로 명시해 cleanup에서 이중 해제 회피.
- `free(NULL)`은 안전하므로 별도 NULL 체크 불필요. `fclose(NULL)`은 UB이므로 NULL 체크 필요.

## 9. 매직 넘버, 매크로, enum

매직 넘버 금지. 의미 있는 상수는 매크로 또는 enum으로 정의한다.

- 관련된 수치 상수 묶음은 enum. (디버거 친화, 타입 신호)
- 단일 컴파일 시간 상수는 `enum`을 선호. `#define`은 차선.
- 함수 같은 매크로는 가능하면 `static inline` 함수로 대체. 부득이 매크로를 써야 하면 인자에 괄호, 본문 do-while(0).

```c
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
```

문자열 리터럴은 매크로화하지 않는다. 가독성이 낮아지고 디버깅이 어렵다. 필요한 경우 `static const char *` 변수로 둔다.

## 10. `<stdint.h>` 사용 범위

폭이 본질적인 곳에만 `<stdint.h>` 사용. 그 외는 기본 정수형.

사용:

- 와이어 포맷(파일, 네트워크 직렬화): `uint16_t`, `int32_t`.
- 이진 프로토콜, 비트 플래그 마스크.
- 픽셀, 오디오 샘플 등 폭이 의미 자체인 데이터.

비사용:

- 일반 카운터, 인덱스: `int`, `size_t`.
- 단순 boolean 의미: `bool`(`<stdbool.h>`).
- 시스템 호출 반환값: 표준 시그니처가 정하는 타입(`ssize_t`, `off_t` 등).

이유는 두 가지다. 코드 가독성이 의도 신호를 드러내고, 표준 라이브러리 시그니처와의 묵시 변환 경고가 줄어든다. 모든 정수를 `uint32_t` 류로 통일하면 의도 정보가 사라진다. (BSD 고전의 `u_int32_t`류는 채택하지 않는다 — C11 표준형 사용.)

## 11. 헤더와 모듈 구조

- 헤더 한 개당 모듈 한 개. `module/foo.h` ↔ `module/foo.c`.
- **헤더 가드는 include guard**(KNF 전통): `MODULE_FOO_H` 형식. 선행 밑줄
  금지(예약 식별자). `#pragma once`는 쓰지 않는다. [구판에서 반전]
- 헤더는 자체 포함 가능해야 한다. 필요한 의존 헤더를 자체 `#include`로 가져온다.
- 공개 API 헤더에 내부 구현 디테일 노출 금지. opaque struct로 감춘다.
- 헤더 안에서 다른 헤더에 의존성을 강제하는 일은 피한다. 필요한 전방 선언(forward declaration)으로 의존성을 줄인다.
- 내부 헬퍼 함수는 모두 `static`. 외부 노출 의도가 없는 심볼이 링크 단계에서 새지 않게 한다.

## 12. UB와 메모리 안전

코드 작성 직후 명시적으로 점검할 항목.

- 배열 경계: 인덱스 범위. `sizeof(arr) / sizeof((arr)[0])`로 길이 계산. 포인터 매개변수에 sizeof 금지.
- NULL 역참조: 외부에서 받은 포인터는 함수 진입 게이트에서 점검(`== NULL` 명시 비교, §4).
- 정수 오버플로: `size_t` 곱셈에서 특히 주의. 필요한 경우 명시적 한계 검사 또는 `__builtin_mul_overflow` 가정(CLAUDE.md에서 컴파일러 결정 시).
- 부호 변환: signed ↔ unsigned 묵시 변환에서 경고가 나면 명시적 cast로 의도를 드러내거나 타입 자체를 재설계.
- 해제 후 사용 차단: `free(p)` 후 같은 스코프에서 다시 쓸 가능성이 있으면 `p = NULL` 대입.
- 초기화되지 않은 자동 변수 읽기 금지. 모든 자동 변수는 선언 시 초기화 또는 첫 사용 전 명시적 대입.
- strict-aliasing 위반 금지. 폭 변환은 `union` 또는 `memcpy`.
- 가변 인자: `printf` 계열 형식 문자열에 외부 입력 직접 사용 금지(`-Wformat-security`).

검출 도구는 ASan, UBSan, `scan-build`, `clang-tidy`를 기본 가정으로 둔다. 활성화 여부는 CLAUDE.md.

## 13. 자체 리뷰 체크리스트

c-executor는 코드 생성 직후 본 목록을 모두 점검한다.

- [ ] 네이밍이 §2 준수. 공개 심볼에 모듈 접두사 부착.
- [ ] 포인터 `*` 변수 쪽 부착. 한 줄 한 포인터 변수 선언.
- [ ] 포인터 `== NULL`·정수 `== 0` 명시 비교. `!`는 bool에만.
- [ ] 스코프 접두사(`g_`, `s_`, `out_`) 일관 적용.
- [ ] opaque만 typedef. 가시 layout은 `struct tag` 사용.
- [ ] 함수 포인터 typedef는 `_fn` 또는 `_cb`.
- [ ] 탭 들여쓰기, 연속행 4칸 공백. 공백 혼용 없음.
- [ ] KNF 함수 정의(반환형 한 줄, 이름 0열). `return (값);` 괄호.
- [ ] 선언은 블록 선두, 크기→알파벳 정렬.
- [ ] `//` 주석만(`/* */` 없음). 주석 극단 최소화 — 스펙 앵커·불변식·비자명 why만.
- [ ] 리소스가 있는 함수는 `goto cleanup` 단일 레이블 적용.
- [ ] 매직 넘버 없음. 매크로 또는 enum으로 명명.
- [ ] `<stdint.h>` 사용처가 wire, binary, 픽셀 등 폭이 본질인 곳.
- [ ] 헤더 가드 `MODULE_FOO_H` 형식(#pragma once 없음).
- [ ] §12 UB 잠재 위치 점검(배열 경계, NULL, 오버플로, 부호 변환, 초기화).
- [ ] 헤더 자체 포함성. 내부 구조 노출 없음. 내부 헬퍼는 모두 static.
- [ ] 함수가 한 가지만 한다.
- [ ] 프로젝트 기존 패턴과 일관성.

## 14. 본 문서가 다루지 않는 것

다음은 본 문서의 영역이 아니다. 프로젝트의 CLAUDE.md에서 정의된다.

- 빌드 도구 선택(make, CMake, Meson 등).
- 컴파일러 종류와 표준 라이브러리 구체 버전.
- 외부 의존성 관리 정책.
- 테스트 프레임워크 선택과 CI 게이트.
- 정적 분석 도구 활성화 옵션 구체값.
- Doxygen 등 문서화 도구 사용 여부.

c-executor는 위 결정을 가정으로 받아 코드 작성과 자체 리뷰에만 집중한다.
