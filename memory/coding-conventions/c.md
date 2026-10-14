# C 코딩 컨벤션

베이스: **BSD KNF (style(9)) 계보** + C11 표준. c-executor 에이전트는 코드 작성과
자체 리뷰 시 본 문서를 정본으로 참조한다.

계보 선언(2026-07-10 개정, 2026-10-15 재개정): 본 컨벤션은 벨 연구소 Research
UNIX(V6/V7, K&R) → 4BSD → FreeBSD/OpenBSD style(9)로 이어지는 KNF 전통을
기반으로 하고, 그 위에 **하우스 층**(§3 opaque, §7 주석 최소화, §8 cleanup
레이블)을 얹는다. 하우스 층은 계보 밖 의도적 추가이며 각 절에 [하우스] 표기한다.
2026-10-15 재개정에서 네이밍을 V7/K&R 전통(짧은 이름·구조체 멤버 접두사)으로
되돌리고, 주석 표기는 `//`·`/* */` 모두 허용으로 바꿨다.
구판(Linux kernel 베이스, 긴 snake_case·스코프 접두사)에서의 전환이므로, 기존
코드베이스는 재정형 시 반드시 동작 불변 검증(테스트·golden)과 함께 간다.

## 1. 표준과 빌드 가정

- C11 표준(`-std=c11`, MSVC는 `/std:c11`)을 가정한다. MSVC에는 C99 모드가 없고
  VLA를 지원하지 않으므로, MSVC를 포함하는 빌드 매트릭스의 공통 기준이 C11이다.
- **VLA 금지.** C11에서 선택 기능이고 MSVC가 지원하지 않으며, 스택 오버플로 위험이 있다.
  크기가 실행 시간에 정해지는 버퍼는 `malloc`으로 잡는다.
- C11 신규 기능은 필요한 곳에만 쓴다: `_Static_assert`(wire 구조체 크기·오프셋
  검증), `<stdatomic.h>`·`_Thread_local`(멀티스레드), `_Alignas`(버퍼 정렬).
  `_Generic`처럼 전통과 거리가 먼 기능은 쓰지 않는다.
- 컴파일러 경고 최대 가정: `-Wall -Wextra -Wpedantic`. `-Werror` 여부는 프로젝트 결정.
- 폭(width)이 의미 있는 자료형만 `<stdint.h>` (§10). 그 외엔 기본 정수형(`int`, `size_t`, `ssize_t`).
- 호스트 환경은 POSIX를 기본 가정한다. 비POSIX 의존이 필요하면 그 사실을 명시한다.
- 빌드 도구, 의존성 정책, 정적 분석 옵션, CI 게이트는 본 문서의 영역이 아니다. 프로젝트의 CLAUDE.md에서 정의된다.

## 2. 네이밍 (V7/K&R 전통: 짧은 이름)

원칙: **짧은 소문자 이름.** 이름 길이는 스코프에 비례한다 — 지역 변수는 한두
글자나 관용 약어, 파일 스코프는 짧은 단어, 공개 심볼은 짧은 모듈 약어 + 동사.

| 종류 | 형식 | 예 |
|---|---|---|
| 지역 변수 | 관용 약어, 짧은 소문자 | `i`, `n`, `c`, `p`, `cp`, `bp`, `fp`, `buf`, `len`, `nbytes` |
| 내부(static) 함수 | 짧은 소문자 | `grow`, `hash`, `lookup` |
| 공개 함수 | 모듈 약어(2~4자) + 동사, 붙여 씀 | `hmcreate`, `hmget`, `hmput` |
| 전역·정적 변수 | 접두사 없는 짧은 이름 | `nbuckets`, `debug` |
| 출력 파라미터 | 대상 이름 + `p` 접미사 | `lenp`, `valp` |
| 구조체·공용체 멤버 | 태그 약어(1~3자) + `_` 접두사 | `hm_cap`, `pt_x` |
| 매크로, 상수, enum 멤버 | 대문자, 모듈 약어 접두 | `HM_DEFCAP`, `LOG_WARN` |
| Opaque 타입 | 짧은 태그 + `_t` | `hmap_t` |
| 일반 struct/union | tag만, typedef 없음 | `struct point`, `union value` |
| 함수 포인터 typedef | `_fn` 또는 `_cb` | `cmp_fn`, `done_cb` |

- **약어는 관용 약어만** 쓴다(`buf`, `len`, `cnt`, `tmp`, `src`, `dst`, `p`·`cp`·`bp`·`fp`
  같은 포인터 관례). 읽는 사람이 바로 풀 수 없는 자의적 약어는 금지 — 짧게 쓰되
  암호로 만들지 않는다. 단어 구분이 꼭 필요하면 밑줄 하나까지 허용한다.
- **공개 심볼**은 모듈 약어로 충돌을 피한다(libc의 `str*`·`mem*`, `regcomp`·`regexec`
  계보). 약어는 모듈마다 하나로 정하고 그 모듈의 함수·매크로·enum 멤버에 일관 적용한다.
- **구조체·공용체 멤버 접두사**: 초기 C에서 멤버 이름이 모든 구조체에 공통인 하나의
  이름 공간을 쓰던 시절의 관습이다(`p_pid`, `st_size`, `tm_year`, `sin_addr`).
  오늘날의 실익은 grep으로 멤버 사용처를 정확히 찾을 수 있고, `->`/`.` 앞 변수의
  타입을 멤버 이름만으로 알 수 있다는 것이다. 같은 모듈 안에서 약어가 겹치지 않게 한다.
- **출력 파라미터 `p` 접미사**: `sysctl(…, oldlenp, …)` 계보. 포인터를 통해 값을
  돌려준다는 사실을 이름이 알린다.
- [하우스] `_t` 접미사는 opaque typedef에만 쓴다. BSD 시스템 헤더는 `_t`를 널리
  쓰지만 POSIX 예약 패턴이므로 응용 라이브러리인 우리는 opaque 표시로 한정한다.

## 3. 타입과 typedef

원칙: **opaque만 typedef. 가시 layout은 `struct tag` 직접 사용.** [하우스 — opaque `_t`]

```c
/* opaque: 내부 layout 비공개 */
typedef struct hmap hmap_t;
hmap_t *hmcreate(size_t cap);

/* 가시 layout: typedef 없음 */
struct point {
	int	pt_x;
	int	pt_y;
};
void ptmove(struct point *p, int dx, int dy);
```

`struct` 키워드의 유무가 가시성을 알린다(가시 layout이냐 opaque이냐). V7 이래
구조체는 typedef 없이 `struct tag`로 쓰는 전통과 정합한다.

구조체 멤버 선언은 KNF대로 타입과 이름 사이를 탭으로 정렬한다.

함수 포인터는 typedef를 허용하되 접미사를 강제한다.

```c
typedef int (*cmp_fn)(const void *a, const void *b);
typedef void (*done_cb)(void *ctx, int rc);
```

## 4. 포인터, 비교, 전역

포인터 `*`는 변수 쪽에 붙인다. `int *p`, `char **argv`. `int* p` 금지. 한 줄에 여러 포인터 변수 선언은 의미가 모호해지므로 한 줄당 한 변수 선언을 권고한다.

**명시 비교(KNF)**: 포인터는 `== NULL` / `!= NULL`, 정수는 `== 0` / `!= 0`으로
명시 비교한다. `!`는 진짜 bool에만 쓴다.

```c
if (hm == NULL || key == NULL)
	return (RC_EINVAL);
```

전역·정적 변수에는 `g_`·`s_` 같은 스코프 접두사를 붙이지 않는다(전통). 대신 수를
줄이고, 파일 밖에 보일 필요가 없으면 모두 `static`으로 둔다. 출력 파라미터(`p`
접미사, §2)는 반환값으로 줄 수 없을 때만 사용한다(예: 다중 출력, 또는 반환값이
이미 상태 코드인 경우).

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
hmget(hmap_t *hm, const char *key, void **valp)
{
	struct bucket *bp;
	size_t i;
	int rc = 0;

	if (hm == NULL || key == NULL)
		return (RC_EINVAL);
	// ...
}
```

## 6. 함수 정의와 return (KNF)

함수 정의는 **저장 클래스·반환형을 한 줄에, 함수 이름을 다음 줄 0열에** 둔다
(V7 UNIX 이래의 KNF 형식 — grep `^name`으로 정의를 찾을 수 있다).

```c
static int
grow(struct hmap *hm)
{
	// ...
}
```

선언(헤더)에서는 한 줄 형식을 사용한다.

```c
int hmget(hmap_t *hm, const char *key, void **valp);
```

**return 값은 괄호로 감싼다**: `return (0);`, `return (rc);`. 값 없는
return은 `return;`. — KNF의 지문이며 본 컨벤션의 정본 형식.

함수는 한 가지만 하도록 작성한다. 줄 수로 강제 분할하는 룰은 두지 않는다. 분리할 가치가 없는 함수를 억지로 쪼개면 호출 경로가 더 어려워진다.

## 7. 주석

**표기 — `//`와 `/* */` 모두 허용**(2026-10-15 사용자 결정).

- 여러 줄 주석은 KNF 블록 형식을 쓴다.

  ```c
  /*
   * 여러 줄 설명은
   * 이렇게 쓴다.
   */
  ```

- 한 줄 주석과 줄 끝 주석은 `//`와 `/* */` 중 어느 쪽이든 쓰되, 한 파일 안에서는
  한쪽으로 통일한다. 기존 파일은 그 파일의 표기를 따른다.

**분량 — 극단 최소화** [하우스]. 코드로 말한다 규칙을 극도로 엄격히 적용한다.
남길 자격이 있는 주석은 오직 세 종류:

1. **스펙 앵커**: 이 코드가 어느 규범 조항의 구현인지 (예: `// v2.3 §1`)
2. **코드로 표현 불가능한 불변식·전제** (예: `/* 호출 전제: tot <= 2^16 */`)
3. **비자명한 왜(why)** — 이렇게 안 하면 무엇이 깨지는지

그 외 전부 금지: 무엇(what)·어떻게(how)를 설명하는 주석, 섹션 배너·박스 헤더,
자명한 부연, 이력·저자 주석. 주석이 필요해 보이면 먼저 이름과 구조를 고칠 수
있는지 본다 — 주석은 코드 개선 실패의 마지막 수단이다. 공개 API 헤더 주석도 같은
기준: 계약(전제·소유권·오류)만, 산문 금지.

## 8. 리소스 관리: `goto cleanup` 패턴

`malloc`, `fopen`, `pthread_create` 같이 짝이 있는 리소스를 다루는 함수는 단일 cleanup 출구로 정리한다. 중첩 if 회피와 누수 차단이 핵심이다. (BSD 고전의 `goto` 오류 처리 전통 — 레이블명은 `cleanup` 통일. [하우스])

```c
int
loadconf(const char *path, struct conf **cfp)
{
	struct conf *cf = NULL;
	char *buf = NULL;
	FILE *fp = NULL;
	int rc = 0;

	fp = fopen(path, "rb");
	if (fp == NULL) {
		rc = -errno;
		goto cleanup;
	}

	buf = malloc(CF_MAXSIZE);
	if (buf == NULL) {
		rc = -ENOMEM;
		goto cleanup;
	}

	cf = calloc(1, sizeof(*cf));
	if (cf == NULL) {
		rc = -ENOMEM;
		goto cleanup;
	}

	// ... 파싱 ...

	*cfp = cf;
	cf = NULL;	// 소유권 이전

cleanup:
	free(cf);
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
#ifndef nitems
#define nitems(a) (sizeof(a) / sizeof((a)[0]))
#endif
```

`nitems`는 FreeBSD `<sys/param.h>`의 관용 이름이다(함수처럼 쓰이는 관용 매크로라
소문자). 시스템 헤더가 이미 정의한 환경이 있으므로 `#ifndef`로 감싼다.

문자열 리터럴은 매크로화하지 않는다. 가독성이 낮아지고 디버깅이 어렵다. 필요한 경우 `static const char *` 변수로 둔다.

## 10. `<stdint.h>` 사용 범위

폭이 본질적인 곳에만 `<stdint.h>` 사용. 그 외는 기본 정수형.

사용:

- 와이어 포맷(파일, 네트워크 직렬화): `uint16_t`, `int32_t`. 구조체 layout이
  포맷과 일치해야 하면 `_Static_assert`로 크기·오프셋을 검증한다.
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

- 배열 경계: 인덱스 범위. `nitems(arr)`(§9)로 길이 계산. 포인터 매개변수에 sizeof 금지.
- NULL 역참조: 외부에서 받은 포인터는 함수 진입 게이트에서 점검(`== NULL` 명시 비교, §4).
- 정수 오버플로: `size_t` 곱셈에서 특히 주의. 필요한 경우 명시적 한계 검사 또는 `__builtin_mul_overflow` 가정(CLAUDE.md에서 컴파일러 결정 시).
- 부호 변환: signed ↔ unsigned 묵시 변환에서 경고가 나면 명시적 cast로 의도를 드러내거나 타입 자체를 재설계.
- 해제 후 사용 차단: `free(p)` 후 같은 스코프에서 다시 쓸 가능성이 있으면 `p = NULL` 대입.
- 초기화되지 않은 자동 변수 읽기 금지. 모든 자동 변수는 선언 시 초기화 또는 첫 사용 전 명시적 대입.
- strict-aliasing 위반 금지. 폭 변환은 `union` 또는 `memcpy`.
- 가변 인자: `printf` 계열 형식 문자열에 외부 입력 직접 사용 금지(`-Wformat-security`).
- VLA 금지(§1). 실행 시간 크기 버퍼는 힙에.

검출 도구는 ASan, UBSan, `scan-build`, `clang-tidy`를 기본 가정으로 둔다. 활성화 여부는 CLAUDE.md.

## 13. 자체 리뷰 체크리스트

c-executor는 코드 생성 직후 본 목록을 모두 점검한다.

- [ ] 네이밍이 §2 준수: 짧은 이름, 관용 약어만(자의적 약어 없음), 공개 심볼은 모듈 약어 + 동사.
- [ ] 구조체·공용체 멤버에 태그 약어 접두사(`hm_cap`), 멤버 선언 탭 정렬.
- [ ] 전역·정적 변수에 스코프 접두사(`g_`, `s_`) 없음. 출력 파라미터는 `p` 접미사.
- [ ] 포인터 `*` 변수 쪽 부착. 한 줄 한 포인터 변수 선언.
- [ ] 포인터 `== NULL`·정수 `== 0` 명시 비교. `!`는 bool에만.
- [ ] opaque만 typedef(`_t`). 가시 layout은 `struct tag` 사용.
- [ ] 함수 포인터 typedef는 `_fn` 또는 `_cb`.
- [ ] 탭 들여쓰기, 연속행 4칸 공백. 공백 혼용 없음.
- [ ] KNF 함수 정의(반환형 한 줄, 이름 0열). `return (값);` 괄호.
- [ ] 선언은 블록 선두, 크기→알파벳 정렬.
- [ ] 주석: 여러 줄은 KNF 블록 형식, 한 줄 표기는 파일 안에서 통일. 분량 극단 최소화 — 스펙 앵커·불변식·비자명 why만.
- [ ] 리소스가 있는 함수는 `goto cleanup` 단일 레이블 적용.
- [ ] 매직 넘버 없음. 매크로 또는 enum으로 명명.
- [ ] `<stdint.h>` 사용처가 wire, binary, 픽셀 등 폭이 본질인 곳.
- [ ] VLA 없음. C11 신규 기능은 필요한 곳에만(`_Generic` 미사용).
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
