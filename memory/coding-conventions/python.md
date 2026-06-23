# Python 코딩 컨벤션

베이스: Python 3.12+, mypy strict, Ruff(포매터+린터), uv(패키지 관리). py-executor는 코드 작성과 자체 리뷰 시 본 문서를 정본으로 참조한다.

## 1. 표준과 빌드 가정

- Python 3.12 이상을 가정. 그 이하 호환은 명시적 요구가 있을 때만.
- 타입 검사는 `mypy --strict` 가정. 모든 함수에 타입 힌트.
- 포매터·린터는 Ruff. 별도 black 사용 없음.
- 패키지 관리는 uv. `requirements.txt` 직접 작성은 회피.
- 가상환경은 프로젝트 단위로 분리(`.venv`).
- 마이너 버전 구체값, 의존성 그룹 정책, 웹/ORM/테스트 프레임워크 선택은 본 문서의 영역이 아니다. 프로젝트의 CLAUDE.md에서 정의된다.

## 2. 네이밍

| 종류 | 형식 | 예 |
|---|---|---|
| 변수, 함수, 메서드 | snake_case | `user_count`, `fetch_profile` |
| 클래스 | PascalCase | `UserRepository`, `HttpClient` |
| 상수 (모듈 수준) | UPPER_SNAKE_CASE | `MAX_RETRY`, `DEFAULT_TIMEOUT_MS` |
| 모듈, 패키지 | snake_case | `user_repo`, `http_client` |
| Type alias / TypeVar | PascalCase | `UserId = int`, `T = TypeVar('T')` |
| Private (모듈/클래스 내부) | `_` 단일 prefix | `_internal_helper` |
| Name mangling | `__` (회피) | 사용 금지 |

double underscore prefix(`__foo`)는 name mangling을 유발하므로 회피한다. 외부에 노출하기 싫은 멤버에도 단일 `_`를 쓴다.

boolean 함수/플래그는 `is_`, `has_`, `can_`, `should_` 접두사.

```python
is_authenticated: bool
def can_retry(error: Exception) -> bool: ...
```

## 3. 타입 힌트

- 모든 함수/메서드에 매개변수와 반환 타입 명시. 반환이 None이어도 `-> None` 명시.
- nullable은 `T | None` (PEP 604). `Optional[T]` 회피.
- 컬렉션은 `list`, `dict`, `tuple`, `set` 소문자 generics. `typing.List`, `typing.Dict` 회피.
- 입력에는 추상 인터페이스(`Sequence`, `Mapping`, `Iterable`)를 선호. 출력에는 구체 타입.
- TypedDict는 외부 API 응답 같은 dict 구조 문서화에 사용. 내부 모델은 dataclass.
- Generic은 PEP 695 신문법 우선: `def head[T](xs: Sequence[T]) -> T | None:`.
- `Any` 사용은 외부 경계에서만, 즉시 좁힌다.

```python
def parse_user(payload: Mapping[str, object]) -> User: ...
def head[T](xs: Sequence[T]) -> T | None: ...
```

## 4. dataclass와 NamedTuple

dict로 구조화된 데이터를 함수 간에 전달하지 않는다. dataclass 또는 NamedTuple로 모델링한다.

```python
from dataclasses import dataclass

@dataclass(frozen=True, slots=True, kw_only=True)
class UserSummary:
    id: UserId
    display_name: str
    is_premium: bool
```

- 기본은 `frozen=True` + `slots=True` + `kw_only=True`. 불변, 메모리 효율, 인자 순서 의존 차단.
- 변경이 필요한 컨테이너만 `frozen=False`. 사유를 코드 또는 docstring에서 분명히.
- 단순 좌표/튜플 같은 짧은 묶음은 NamedTuple. 메서드가 붙으면 dataclass.

dict는 진정 동적인 키-값 쌍(외부 입력, 캐시 등)에만 사용한다.

## 5. 코드 스타일

- 들여쓰기 4 스페이스. 탭 금지.
- 줄 길이 88자(Ruff 기본).
- **작은따옴표** 우선. docstring은 `"""..."""`.
- trailing comma 항상 (Ruff가 자동 적용).
- 한 줄당 한 import.
- import 순서: 표준 라이브러리 → 서드파티 → 로컬. 그룹 사이 빈 줄. Ruff isort가 자동.

## 6. 공개 API 정의

각 모듈에 `__all__`를 명시해 공개 API를 분명히 한다. wildcard import의 안전성과 mypy의 reexport 추론에 직결된다.

```python
__all__ = ['User', 'UserRepository', 'fetch_user']
```

내부 헬퍼는 `__all__`에서 빼고, 호출 측은 `from module import _helper`를 사용하지 않는다.

## 7. 불변성

- 컬렉션 반환 타입은 가능하면 `tuple`, `frozenset`, 또는 read-only abstract(`Sequence`, `Mapping`).
- dataclass는 §4의 `frozen=True` 기본.
- 함수의 매개변수에 mutable default 금지. `def f(xs: list[int] = []):` 같은 형태 금지. 기본값은 `None`으로 두고 함수 본문에서 초기화한다.

```python
def append_safe(value: int, xs: list[int] | None = None) -> list[int]:
    xs = list(xs) if xs is not None else []
    xs.append(value)
    return xs
```

## 8. 에러 처리

- 구체적 예외 클래스 사용. `Exception`, `BaseException` 광범위 catch 금지(진입점 핸들러 제외).
- 도메인 예외는 패키지 단위로 한 곳에 정의(`exceptions.py`).
- 예외 메시지는 운영자가 원인을 추적할 수 있도록 구체적으로.
- `raise X from Y`로 원인 체인 보존.
- 단순 lookup에서 not-found는 `None` 반환이 자연스러운 경우가 많다. 예외와 결과 타입 사이의 선택을 의식적으로.

## 9. 비동기

- `async def` + `await`. 콜백/스레드는 정말 필요한 경우만.
- `asyncio.create_task`로 만든 태스크는 누구의 책임인지 명확히 한다. 도망 태스크 금지.
- 외부 IO는 비동기 함수로 표현. 동기 호출과 섞이는 경우 `asyncio.to_thread`.
- structured concurrency: `asyncio.TaskGroup`(3.11+) 사용. 자식 태스크의 예외가 부모에서 일관 처리된다.

```python
async with asyncio.TaskGroup() as tg:
    task_a = tg.create_task(load_a())
    task_b = tg.create_task(load_b())
```

## 10. 로깅과 진단

- `print` 금지(스크립트 진입점 제외). `logging` 모듈 사용.
- 로거는 모듈별로 `logger = logging.getLogger(__name__)`.
- 포맷팅은 `logger.info('user %s loaded', user_id)` 식 lazy 형식. 비용 큰 메시지에는 f-string 회피.
- 예외 로깅은 `logger.exception(...)`로 traceback 자동 포함.

## 11. 테스트 형식

테스트 프레임워크 선택은 CLAUDE.md에서 결정한다. 작성 형식만 짧게 둔다.

- 테스트 함수 이름은 `test_<대상>_<상황>` 형식.
- 픽스처는 가까운 scope에서 정의. 광역 conftest 남용 회피.
- assertion 메시지는 실패 원인을 즉시 추적 가능하게.

## 12. 자체 리뷰 체크리스트

py-executor는 코드 생성 직후 본 목록을 모두 점검한다.

- [ ] 네이밍 §2 준수. 단일 `_` private, double underscore 회피.
- [ ] 모든 함수에 타입 힌트(매개변수 + 반환). nullable은 `T | None`.
- [ ] dict 전달 없이 dataclass/NamedTuple 사용.
- [ ] dataclass는 `frozen=True, slots=True, kw_only=True` 기본.
- [ ] `__all__` 명시.
- [ ] 4 스페이스, 88자, 작은따옴표, trailing comma.
- [ ] mutable default 인자 없음.
- [ ] 광범위 예외 catch 없음. `raise ... from` 으로 체인 보존.
- [ ] `print` 미사용(스크립트 진입점 제외). `logging` 사용.
- [ ] `async`는 `TaskGroup` 등 structured concurrency.
- [ ] mypy strict 통과 가능한 형식.
- [ ] 프로젝트 기존 패턴과 일관성.

## 13. 본 문서가 다루지 않는 것

다음은 본 문서의 영역이 아니다. 프로젝트의 CLAUDE.md에서 정의된다.

- Python 마이너 버전 구체값.
- 의존성 그룹 정책(`dev`/`test`/`docs`).
- 웹 프레임워크(FastAPI/Django/Flask) 선택.
- ORM 선택과 마이그레이션 도구.
- 테스트 프레임워크(pytest vs unittest).
- CI 게이트 구체 옵션.

py-executor는 위 결정을 가정으로 받아 코드 작성과 자체 리뷰에만 집중한다.
