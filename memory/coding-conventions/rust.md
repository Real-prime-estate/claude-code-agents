# Rust 코딩 컨벤션 (확정 2026-10-08)

> 2026-10-08 사용자와 항목별로 논의해 확정했다(★ = 사용자가 직접 고른 결정, 나머지 규칙도 같은 날 일괄 확정).
> 예제는 전부 실제로 `cargo fmt --check`·`cargo clippy`(아래 §1 린트)·`cargo test`를 통과한 코드다
> (rust 1.93.1, edition 2024).

베이스: **BSD KNF C 개발자가 바로 읽히는 Rust.** 원본은 `c.md`(BSD KNF style(9) 계보 + 하우스 층)이고,
절 번호를 c.md와 같게 맞춰 절마다 Rust 대응을 둔다. rust-executor는 코드 작성과 자체 리뷰에서
본 문서를 정본으로 참조한다.

원칙:
- **★문법은 최대한 명시적으로 쓴다(2026-10-08 사용자).** C는 문법이 명시적이고, libc·POSIX의 숨은 동작은 공개돼 있어 다 안다. Rust도 최소한 문법만은 C처럼 드러나게 적는다. 컴파일러가 대신 해 주는 일(숨은 분기 `?`, 숨은 반환 꼬리 식, 숨은 루프 함수 사슬, 숨은 빌림 메서드 호출)을 우리 코드에서는 쓰지 않는다.
- 읽는 사람은 C 개발자다. 제어 흐름이 줄 단위로 보이게 쓴다.
- 컴파일러·rustfmt·clippy가 강제할 수 있는 규칙은 설정으로 강제한다. 강제 못 하는 규칙만 리뷰 체크리스트에 둔다.
- 컴파일러가 오류로 막거나 stable 도구로 불가능한 것은 C 모양을 포기하고 "C와 다른 점"으로 명시한다. 경고(lint)를 끄는 것은 사용자가 결정한 자리에서만 한다(§1 ★ 표시).

## 1. 표준과 빌드 가정

- stable 툴체인, **edition 2024**. nightly 전용 기능 금지.
- **★`unsafe` 금지**: `[lints.rust] unsafe_code = "forbid"`. 예외 없음(필요해 보이면 설계를 바꾼다).
- 린트는 워크스페이스 `Cargo.toml`에 둔다. 아래가 본 컨벤션의 강제 장치다.

```toml
[lints.rust]
unsafe_code = "forbid"
unused_parens = "allow"       # ★ return (값); 괄호(§6)

[lints.clippy]
question_mark_used = "deny"   # ★ `?` 금지 — match로 펼친다(§8)
implicit_return = "deny"      # ★ 꼬리 식 반환 금지 — return 명시(§6)
needless_return = "allow"     # 위와 짝: 명시 return을 경고하지 않게
unwrap_used = "deny"          # 운영 코드에서 panic 경로 금지(§12)
expect_used = "deny"
panic = "deny"
indexing_slicing = "deny"     # buf[i]는 범위 밖에서 panic — get() 사용(§12)
as_conversions = "deny"       # 조용한 절단·부호 변환 금지 — from/try_from(§10)
needless_late_init = "allow"  # ★ 선두 선언 후 한 번 대입(§5)
let_and_return = "allow"      # `let v = …; return v;` 허용(§6)

[profile.release]
overflow-checks = true        # release에서도 정수 오버플로를 잡는다(§12)
```

`clippy.toml`(시험 코드 완화):

```toml
allow-unwrap-in-tests = true
allow-expect-in-tests = true
allow-panic-in-tests = true
allow-indexing-slicing-in-tests = true
```

- 빌드 도구·의존성 정책·CI 게이트 구체값은 §14대로 프로젝트 CLAUDE.md 소관이다.

## 2. 네이밍

Rust 네이밍은 컴파일러 린트가 강제하므로 **Rust 표준을 따른다**(C와 다른 점).

| 종류 | 형식 | 예 |
|---|---|---|
| 변수, 함수, 모듈 | snake_case | `load_config`, `device_id` |
| 타입(struct·enum)·트레이트 | UpperCamelCase | `Config`, `ConfigError` |
| enum 멤버 | UpperCamelCase | `Role::SuperAdmin` |
| 상수·static | UPPER_SNAKE_CASE | `MAX_PAGE_SIZE` |

- [C 대응] C의 공개 심볼 모듈 약어(`hmget`)는 쓰지 않는다. **모듈 경로가 그 역할을 한다**: 다른 모듈의 함수는 `config::port(&cfg)`처럼 모듈 경로를 붙여 부른다(함수를 `use`로 끌어와 맨 이름으로 부르지 않는다 — 타입·상수·enum만 `use`). 같은 모듈 안에서 여러 개념이 섞여 이름이 모호하면 동사+목적어로 구체화한다(`point_translate`처럼 C식 이름도 허용).
- [C 대응] `_t` 접미사는 쓰지 않는다. opaque 여부는 필드 가시성이 알린다(§3).
- [C 대응] 스코프 접두사(`g_`·`s_`·`out_`)는 쓰지 않는다(C도 2026-10-15부터 쓰지 않는다). 전역 가변 상태(`static mut`)는 unsafe라 원천 금지이고, 출력 파라미터 대신 반환값(튜플·struct·`Result`)으로 돌려준다.

## 3. 타입과 가시성

원칙: **c.md의 "opaque만 typedef"는 필드 가시성으로 옮긴다.**

```rust
// opaque: 필드 비공개, 접근은 함수로
pub struct Config {
	port: u16,
}

// 가시 layout: 필드 공개
pub struct Point {
	pub x: i64,
	pub y: i64,
}
```

- **★우리 타입의 동작은 자유 함수로 쓴다(2026-10-08 사용자 결정).** 첫 인자로 구조체 참조를 받는 C 모양이다. 호출하는 쪽에 빌림(`&cfg`·`&mut p`)이 그대로 보이고, 정의를 `^pub fn port`로 grep할 수 있다. `impl` 블록 메서드(`cfg.port()`)는 쓰지 않는다 — 메서드 호출은 컴파일러가 `&`·`&mut`·역참조를 몰래 붙이고(자동 빌림), 이름을 타입과 범위 안 트레이트에서 찾아 출처가 안 보인다.
  - 예외: 트레이트 구현이 요구하는 메서드(`impl fmt::Display`의 `fmt`, serde 등)만 메서드 모양으로 쓴다.
  - 생성자도 자유 함수다(`config::new(…)`, `Config::new` 아님).
- **★표준 라이브러리·크레이트 호출도 명시형으로 쓴다(2026-10-08 사용자 결정).** 메서드 문법 대신 `타입::함수(&값, …)` 또는 `트레이트::함수(&값, …)`로 부른다. 빌림과 함수의 출처가 호출 줄에 드러난다.

| 메서드 문법(쓰지 않음) | 명시형(쓴다) |
|---|---|
| `fp.metadata()` | `File::metadata(&fp)` |
| `fp.read_to_string(&mut buf)` | `Read::read_to_string(&mut fp, &mut buf)` |
| `rest.trim()` | `str::trim(rest)` |
| `buf.get(i)` | `<[u8]>::get(buf, i)` |
| `v.push(x)` | `Vec::push(&mut v, x)` |
| `a.checked_add(b)` | `usize::checked_add(a, b)` |
| `text.lines()` (for 헤더 포함) | `str::lines(text)` |

  - **인자 자동 변환도 드러낸다**: `&String`을 `&str` 인자에 넘길 때 `String::as_str(&s)`, `&Vec<T>`를 `&[T]`에 넘길 때 `Vec::as_slice(&v)`. 컴파일러의 deref 강제 변환(deref coercion)에 기대지 않는다.
  - **예외 — 빌더 API**: AWS SDK·axum처럼 빌더 사슬로 설계된 크레이트 API는 입출력 바깥층(async 경계)에서만 메서드 사슬을 허용한다(`client.get_item().table_name(t).key(k).send().await`). 사슬의 결과는 곧바로 `match`로 받고, 핵심 로직 크레이트에는 빌더 호출이 없다.
  - 연산자(`==`, `+`, 비교)는 그대로 쓴다. `PartialEq::eq(&a, &b)`로 풀지 않는다.
  - clippy는 메서드 문법을 막는 린트가 없다 — 리뷰 체크리스트 항목이다.

```rust
pub fn port(cfg: &Config) -> u16 {
	return (cfg.port);
}

pub fn listen_port(path: &str) -> Result<u16, config::ConfigError> {
	let cfg: config::Config;
	let port: u16;

	cfg = match config::load_config(path) {
		Ok(c) => c,
		Err(e) => return (Err(e)),
	};
	port = config::port(&cfg);
	return (Ok(port));
}
```

- `type` 별칭은 거의 쓰지 않는다. 쓰면 같은 타입에 이름만 붙는다(C typedef와 같은 함정).
- 함수 포인터가 필요하면 `fn(&Req) -> Resp` 타입을 쓴다. 클로저 타입·`Box<dyn Fn>`은 프레임워크가 요구할 때만(§4).
- **★제네릭 함수·사용자 정의 트레이트는 금지(2026-10-08 사용자 결정).** 제네릭은 안전하지만(정의 시점 타입 검사, 텍스트 치환 아님) 호출 줄만 보고 어느 구현이 불리는지 안 보여 명시성 원칙에 어긋난다.
  - 허용 목록: 표준 derive(`Debug`·`Clone`·`Copy`·`PartialEq`·`Eq`), 손으로 쓰는 `impl fmt::Display`, 의존 크레이트가 요구하는 트레이트 구현(serde 직렬화 등).
  - 타입별로 다른 동작은 **enum + `match`**로 쓴다(C의 switch 감각 — 분기가 눈에 보인다).
  - 크레이트 API가 제네릭을 받는 자리(예: `Vec<T>`, `HashMap<K, V>`, 크레이트 함수의 제네릭 인자)는 쓰는 쪽이므로 해당하지 않는다. 금지는 우리가 `fn f<T>`·`trait X`를 정의하는 것이다.
- 수명 표기는 최소화한다. 빌림이 복잡해지면 `clone()`·소유 타입·`Arc`로 푼다(성능보다 읽기 우선).

## 4. 비교, 분기, 반복

- **명시 비교(KNF)**: 정수는 `== 0`, `!= 0`처럼 명시한다. `!`는 진짜 `bool`에만.
- `Option`·`Result`는 **`match`가 기본**이다. `Option`의 있음/없음만 볼 때는 `if let Some(x) = …`(else 없이) 또는 `Option::is_none(&x)`를 허용한다.
- **★`let … else` 금지**: 숨은 반환이라 `match`로 쓴다.
- **★함수 사슬 대신 `for`**: `.iter().filter().map().count()` 같은 사슬을 쓰지 않는다. `for` 헤더에는 `&v`나 명시형 반복자 하나(`str::lines(text)`)만 둔다.
- **★클로저 최소**: 표준·크레이트 API가 클로저만 받을 때만 쓴다. 쓸 때는 본문에서 이름 붙은 함수를 부른다. clippy `implicit_return`이 클로저에도 `return`을 요구하므로 짧은 클로저도 `|x| { return f(x); }` 꼴이 된다(그 자체가 사슬을 피할 이유다).
- **★매크로 정의 금지**(`macro_rules!`, §9): 함수로 쓴다. 표준 매크로(`write!`·`format!`·`vec!`·`assert_eq!` 등)와 derive는 허용.

```rust
pub fn can_read_device(grant: &Grant, device_id: &str) -> bool {
	if grant.role == Role::SuperAdmin {
		return (true);
	}
	for id in &grant.device_ids {
		if id == device_id {
			return (true);
		}
	}
	return (false);
}

pub fn count_readable(grant: &Grant, ids: &[String]) -> usize {
	let mut n: usize = 0;

	for id in ids {
		if can_read_device(grant, id) {
			n += 1;
		}
	}
	return (n);
}
```

## 5. 들여쓰기, 줄, 중괄호, 선언

★`rustfmt.toml`:

```toml
edition = "2024"
hard_tabs = true
tab_spaces = 8
max_width = 80
```

- 탭 들여쓰기, 폭 8, 80열(KNF와 같다). 서식은 rustfmt가 정본이고 손으로 맞추지 않는다.
- [C와 다른 점] **함수 여는 중괄호는 같은 줄**이다. 다음 줄 0열(`brace_style = "AlwaysNextLine"`)은 rustfmt nightly 전용이라 stable에서 쓸 수 없다. 연속행 들여쓰기도 rustfmt 규칙을 따른다(4칸 공백 아님).
- 단일 문 `if`도 중괄호는 필수다(Rust 문법).
- 무한 루프는 `loop`(= `for (;;)`).
- **★선언은 블록 선두에 모은다(KNF, 2026-10-08 사용자 결정).** 타입을 적어 값 없이 선언하고(`let fp: File;`), 본문에서 한 번 대입한다. 선언부와 본문은 빈 줄로 가른다.
  - 안전성: 대입 전 읽기는 컴파일 오류이고, `mut`이 아니면 두 번 대입도 컴파일 오류다. 그래서 C의 "초기화 안 된 변수 읽기"가 원천 차단된다. clippy `needless_late_init`는 끈다(§1).
  - 단순 초기화(리터럴, `String::new()`·`Vec::new()` 같은 빈 값)는 선언에서 해도 된다. 계산이 필요한 초기화는 본문으로 내린다(c.md §5와 같다).
  - 정렬은 c.md의 "크기순"이 Rust 타입에서는 보이지 않으므로 **처음 쓰이는 순서**로 둔다.
  - 불변(`let`)이 기본이고 `let mut`은 꼭 바뀌는 것만.
  - 루프·`match` 갈래처럼 안쪽 블록의 변수는 그 블록 선두에 선언한다.
- 선두 선언의 예외와 주의(C와 다른 점):
  - **이름을 쓸 수 없는 타입**(클로저, `impl Iterator`, `async` 블록의 future)은 선두에 선언할 수 없다. 이런 값만 사용 지점에서 `let x = …;`로 선언한다. 이 규약은 클로저·함수 사슬을 최소로 하므로 드물다.
  - **같은 이름 재바인딩(`let s = str::trim(s);`) 금지.** 새 이름을 짓는다(`let trimmed: &str;`).
  - **해제 순서**: 값은 블록 끝에서 선언의 역순으로 Drop된다. 파일·잠금처럼 해제 시점이 중요한 값은 선언 순서를 의식하고, 일찍 놓아야 하면 안쪽 블록으로 감싼다.
  - 긴 타입은 줄이 길어진다. 80열을 넘으면 rustfmt가 줄바꿈한다. `type` 별칭으로 줄이지는 않는다(§3).

## 6. 함수 정의와 return

- [C와 다른 점] 함수 이름은 `fn` 뒤 같은 줄이다(rustfmt). 정의 찾기는 `^pub fn name`·`^fn name`으로 grep한다.
- **★명시적 `return` 의무**: 값을 돌려주는 모든 함수·클로저는 `return (값);`으로 끝난다. 꼬리 식 반환 금지. clippy `implicit_return`이 강제한다.
- **★단위 `()` 함수도 끝에 `return;`**을 쓴다. clippy는 이것을 강제하지 못한다(꼬리가 `;` 문이면 경고 없음) — 리뷰 체크리스트 항목이다.
- **★return 값은 괄호로 감싼다(KNF, 2026-10-08 사용자 결정)**: `return (0);`, `return (Ok(cfg));`, 갈래 안에서도 `Err(e) => return (Err(e)),`. 값 없는 return은 `return;`. rustfmt는 이 괄호를 지우지 않는다. rustc `unused_parens`는 끈다(§1) — 그래서 다른 자리의 불필요한 괄호도 경고되지 않으니 리뷰에서 본다.
- [C와 다른 점] 함수 여는 중괄호는 stable rustfmt대로 같은 줄이고, 함수 이름을 다음 줄 0열에 두는 형식은 rustfmt에 옵션이 없어 적용하지 않는다(10-08 사용자 결정 — nightly rustfmt 미사용).
- `if`·`match`를 값으로 대입하는 것은 허용한다(`v = if flag { 1 } else { 2 };`). 단 함수의 마지막 줄은 언제나 `return`이다.
- 끝에 `match`가 오고 모든 갈래가 `return`하면 그대로 둔다(clippy도 통과).

```rust
pub fn point_translate(p: &mut Point, dx: i64, dy: i64) {
	p.x += dx;
	p.y += dy;
	return;
}

pub fn pick(flag: bool) -> u32 {
	let v: u32;

	v = if flag { 1 } else { 2 };
	return (v);
}
```

- **★async는 바깥층에만**: HTTP 핸들러·AWS 호출 같은 입출력 경계만 `async fn`이다. 판정·계산·검증 같은 핵심 로직은 동기 순수 함수로 두고 async 쪽에서 부른다. 핵심 크레이트에는 async 런타임 의존을 두지 않는다.

```rust
pub async fn handle_page(req: Request) -> Result<usize, WireError> {
	let n: Result<usize, WireError>;

	n = page_bytes(req.count, req.size);
	return (n);
}
```

- 함수는 한 가지만 한다. 줄 수로 강제 분할하지 않는다(c.md와 같다).

## 7. 주석 스타일

분량 기준은 c.md §7을 따른다. 표기는 Rust 별도 규칙이다(C는 2026-10-15부터 `//`·`/* */` 모두 허용하지만 Rust는 그대로).
- **`//` 전용.** `/* */` 금지.
- 공개 API 문서는 `///`만 허용하고 c.md 기준(계약: 전제·소유권·오류)만 쓴다. 산문 금지.
- 남길 자격: 스펙 앵커 · 코드로 표현 불가한 불변식 · 비자명한 why. 그 외 금지.

## 8. 오류와 리소스: `goto cleanup` → `match` + Drop

**★오류 전파는 `?` 금지 — `match`로 펼쳐 쓴다.** 오류 갈래가 눈에 보이는 조기 `return`이 된다(KNF의 `if (rc != 0) goto cleanup;` 감각).

- 리소스 정리는 Drop(RAII)이 맡는다. `File`·소켓·잠금은 스코프를 벗어나면 닫힌다. 그래서 `cleanup` 레이블에 해당하는 코드가 없다.
- 소유권 이전은 이동(move)으로 컴파일러가 추적한다. c.md의 "이전 후 NULL 대입"은 필요 없다.
- 오류 타입은 **모듈마다 `enum XxxError`** 하나. 원인 오류를 갈래에 싣는다. **★`impl fmt::Display`는 손으로 쓴다(2026-10-08 사용자 결정).** thiserror(derive가 Display를 대신 생성 — 생성 코드가 소스에 안 보임)와 anyhow(오류를 하나로 뭉뚱그려 `?`와 쓰는 설계)는 쓰지 않는다. derive는 serde처럼 손으로 대신할 방법이 없는 것과 표준 derive만 쓴다.
- 운영 코드에서 `unwrap()`·`expect()`·`panic!` 금지(§1 린트). 시험 코드는 허용.

```rust
const MAX_CONFIG_SIZE: u64 = 64 * 1024;

#[derive(Debug)]
pub enum ConfigError {
	Open(std::io::Error),
	Read(std::io::Error),
	TooLarge,
	Parse(&'static str),
}

pub fn load_config(path: &str) -> Result<Config, ConfigError> {
	let mut fp: File;
	let meta: Metadata;
	let mut buf = String::new();
	let cfg: Config;

	fp = match File::open(path) {
		Ok(f) => f,
		Err(e) => return (Err(ConfigError::Open(e))),
	};
	meta = match File::metadata(&fp) {
		Ok(m) => m,
		Err(e) => return (Err(ConfigError::Read(e))),
	};
	if Metadata::len(&meta) > MAX_CONFIG_SIZE {
		return (Err(ConfigError::TooLarge));
	}
	match Read::read_to_string(&mut fp, &mut buf) {
		Ok(_) => {}
		Err(e) => return (Err(ConfigError::Read(e))),
	}
	cfg = match parse_config(String::as_str(&buf)) {
		Ok(c) => c,
		Err(e) => return (Err(e)),
	};
	return (Ok(cfg));
}

fn parse_config(text: &str) -> Result<Config, ConfigError> {
	for line in str::lines(text) {
		let rest: &str;
		let port: u16;

		rest = match str::strip_prefix(line, "port=") {
			Some(r) => r,
			None => continue,
		};
		port = match str::parse::<u16>(str::trim(rest)) {
			Ok(p) => p,
			Err(_) => return (Err(ConfigError::Parse("port"))),
		};
		return (Ok(Config { port }));
	}
	return (Err(ConfigError::Parse("missing port")));
}
```

(위 `fp`는 함수가 어느 `return`으로 나가든 Drop으로 닫힌다.)

```rust
impl fmt::Display for ConfigError {
	fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
		match self {
			ConfigError::Open(e) => {
				return (write!(f, "open: {e}"));
			}
			ConfigError::Read(e) => {
				return (write!(f, "read: {e}"));
			}
			ConfigError::TooLarge => {
				return (write!(f, "config too large"));
			}
			ConfigError::Parse(what) => {
				return (write!(f, "parse: {what}"));
			}
		}
	}
}
```

## 9. 매직 넘버, 상수, enum

- 매직 넘버 금지. 단일 상수는 `const`, 관련 수치 묶음은 `enum`(필요하면 명시 판별값).
- 문자열 상수는 `const NAME: &str = "…";`(c.md의 `static const char *` 대응).
- **★`macro_rules!`는 정의하지 않는다(2026-10-08 사용자 결정).** c.md의 "함수 같은 매크로 → static inline"은 Rust에서 그냥 함수다. 인라인 여부는 컴파일러가 정한다.
  - 이유: 우리 규약에서 매크로가 당기는 자리는 거의 `match … Err(e) => return (Err(e))` 반복 줄이기뿐인데, 그것을 매크로로 감싸면 금지한 `?`와 같은 숨은 반환이 되살아난다.
  - 쓰는 것은 표준 매크로(`write!`·`format!`·`vec!`·`assert_eq!` 등)와 derive뿐이다.

```rust
pub const MAX_PAGE_SIZE: usize = 100;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogLevel {
	Info = 1,
	Warn = 2,
}
```

## 10. 정수 폭과 변환

c.md §10(폭이 본질인 곳에만 고정 폭)의 Rust 대응. Rust에는 `int`가 없으므로 기준을 이렇게 둔다.
- 인덱스·길이·개수: `usize`.
- 와이어 포맷·바이너리·외부 계약(DB 숫자, JSON 필드)의 폭이 정해진 값: 그 폭(`u16`·`i64` 등).
- **★그 밖의 일반 정수: `i64`(2026-10-08 사용자 결정).** 64비트 서버이고 금액(원 단위 21억 초과 가능)·밀리초 시각·누적 개수처럼 32비트를 넘기 쉬운 값이 많다. 선두 선언에서 타입을 적으므로(§5) 리터럴 기본형 `i32`에 기대는 일은 없다.
- **`as` 변환 금지**(§1 린트). 넓히는 변환은 `u64::from(x)`, 좁히는 변환은 `u16::try_from(n)`을 `match`로 받는다.

```rust
pub fn to_u16(n: u64) -> Result<u16, WireError> {
	match u16::try_from(n) {
		Ok(v) => return (Ok(v)),
		Err(_) => return (Err(WireError::Overflow)),
	}
}
```

## 11. 모듈과 크레이트 구조

- 파일 하나 = 모듈 하나. `foo.rs`(+ 하위가 있으면 `foo/` 폴더). `mod.rs`는 쓰지 않는다.
- 가시성은 최소: 기본 비공개, 크레이트 안에서만 쓰면 `pub(crate)`, 밖에 내보낼 것만 `pub`(c.md의 "내부 헬퍼는 static").
- glob import(`use foo::*`) 금지. 시험 모듈의 `use super::*;`만 허용.
- 핵심 로직(동기 순수 함수)과 입출력(async·AWS·DB)을 크레이트로 가른다. 구체 크레이트 배치는 프로젝트 CLAUDE.md 소관이다(§14).

## 12. panic과 메모리 안전

C의 UB 점검표를 Rust에서는 "panic 경로 점검표"로 바꾼다. safe Rust에 UB는 없지만 panic은 서버를 죽인다.

- 배열·슬라이스 인덱싱 `buf[i]`·`buf[a..b]` 금지 → `<[u8]>::get(buf, i)`·`<[u8]>::get(buf, a..b)`를 `match`(§1 `indexing_slicing`).
- 정수 오버플로: 외부 입력이 들어가는 산술은 `checked_add`·`checked_mul`로 받는다. release도 `overflow-checks = true`라 놓친 오버플로는 조용히 감기지 않고 panic이 된다(조용한 오답보다 낫다).
- 좁히는 변환은 `try_from`(§10).
- `unwrap`·`expect`·`panic!` 금지(§1). 시험 코드는 예외.
- 외부 입력 형식 문자열: `format!`의 형식은 리터럴만 가능하므로 c.md의 형식 문자열 공격은 생기지 않는다.

```rust
pub fn read_u16_be(buf: &[u8], off: usize) -> Result<u16, WireError> {
	let end: usize;
	let bytes: &[u8];
	let mut out: u16 = 0;

	end = match usize::checked_add(off, 2) {
		Some(e) => e,
		None => return (Err(WireError::Overflow)),
	};
	bytes = match <[u8]>::get(buf, off..end) {
		Some(b) => b,
		None => return (Err(WireError::Short)),
	};
	for b in bytes {
		out = (out << 8) | u16::from(*b);
	}
	return (Ok(out));
}

pub fn page_bytes(count: usize, size: usize) -> Result<usize, WireError> {
	match usize::checked_mul(count, size) {
		Some(n) => return (Ok(n)),
		None => return (Err(WireError::Overflow)),
	}
}
```

**★시험 코드도 같은 규칙을 따른다**(선두 선언, 명시형 호출, return 괄호, 단위 함수 `return;`). 완화는 `unwrap`·`expect`·`panic`·인덱싱 허용뿐이다(`clippy.toml`, §1).

```rust
#[cfg(test)]
mod tests {
	use super::*;

	#[test]
	fn reads_big_endian() {
		let buf: [u8; 3] = [0x01, 0x02, 0x03];

		assert_eq!(Result::unwrap(read_u16_be(&buf, 1)), 0x0203);
		assert_eq!(read_u16_be(&buf, 2), Err(WireError::Short));
		return;
	}
}
```

## 13. 자체 리뷰 체크리스트

rust-executor는 코드 생성 직후 아래를 모두 점검한다. 앞의 네 줄은 도구가 잡고, 나머지는 사람 눈(=에이전트 리뷰)이 잡는다.

- [ ] `cargo fmt --check` 통과(탭 8·80열).
- [ ] `cargo clippy --all-targets` 경고 0(§1 린트: `?`·꼬리 식·unwrap·panic·인덱싱·`as`).
- [ ] `cargo test` 통과.
- [ ] `unsafe` 없음(forbid).
- [ ] 단위 `()` 함수도 끝에 `return;`(clippy 미강제).
- [ ] 값 return은 전부 `return (값);` 괄호. return 밖의 불필요한 괄호 없음(`unused_parens`가 꺼져 있어 도구가 못 잡음).
- [ ] `let … else` 없음(clippy 미강제).
- [ ] 함수 사슬 대신 `for`. 클로저는 API가 요구할 때만, 본문은 이름 붙은 함수 호출.
- [ ] `macro_rules!` 정의 없음. 사용자 정의 제네릭·트레이트 없음(허용 목록 밖).
- [ ] async는 입출력 경계에만. 핵심 로직 크레이트에 async 없음.
- [ ] 오류는 모듈별 `enum XxxError` + 손으로 쓴 `Display`. `match`로 펼친 조기 `return`.
- [ ] 외부 입력 산술은 `checked_*`, 좁히는 변환은 `try_from`.
- [ ] 가시성 최소(`pub`은 필요한 것만). glob import 없음.
- [ ] 우리 타입에 `impl` 메서드 없음(트레이트 구현 제외). 다른 모듈 함수는 `module::func(&x)`로 호출.
- [ ] 표준·크레이트 호출은 명시형(`File::metadata(&fp)`). 메서드 사슬은 바깥층 빌더 API(AWS SDK·axum)만. 인자 자동 변환은 `String::as_str` 등으로 드러냄.
- [ ] 선언은 블록 선두(타입 명시, 처음 쓰이는 순서), 본문에서 한 번 대입. 사용 지점 선언은 이름 없는 타입뿐. 같은 이름 재바인딩 없음.
- [ ] 명시 비교(`== 0`), `!`는 bool에만.
- [ ] `//` 주석만, 극단 최소화(스펙 앵커·불변식·비자명 why).
- [ ] 매직 넘버 없음(`const`·`enum`).
- [ ] 함수가 한 가지만 한다.
- [ ] 프로젝트 기존 패턴과 일관성.

## 14. 본 문서가 다루지 않는 것

프로젝트 CLAUDE.md에서 정한다.
- 크레이트 배치(워크스페이스 구성, 바이너리 수), 의존 크레이트 선택과 버전 정책(HTTP 프레임워크·AWS SDK·DB 드라이버).
- 시험 프레임워크 추가 여부, CI 게이트 구체값.
- 로그·추적 형식, 설정 파일 형식.

rust-executor는 위 결정을 가정으로 받아 코드 작성과 자체 리뷰에만 집중한다.

## 부록: 2026-10-08 확정 이력(초안 대비 바뀐 선택)

1. ~~제네릭·트레이트(§3)~~ → 10-08 확정: 정의 금지 + 허용 목록, 타입별 동작은 enum+match.
2. ~~선언 위치(§5)~~ → 10-08 확정: KNF 선두 선언.
3. ~~함수 여는 중괄호(§5·§6)~~ → 10-08 확정: stable rustfmt대로 같은 줄(nightly 미사용).
4. ~~`return (x);` 괄호(§6)~~ → 10-08 확정: KNF대로 괄호 사용, `unused_parens` 허용.
5. ~~메서드 허용 여부~~ → 10-08 확정: 우리 타입은 자유 함수, 메서드는 트레이트 요구 시만.
6. ~~일반 정수 기본형(§10)~~ → 10-08 확정: `i64`.
7. ~~오류 매크로 크레이트(§8)~~ → 10-08 확정: thiserror·anyhow 미사용, Display는 손으로.
8. 추가 확정: 문법 명시성 원칙(머리말), 표준·크레이트 호출 명시형(빌더 예외, §3), `macro_rules!` 정의 금지(§9), rustfmt 탭 8·80열·`let…else` 금지·`for`·클로저 최소·async 바깥층(일괄), 시험 코드도 같은 규칙(§12).
