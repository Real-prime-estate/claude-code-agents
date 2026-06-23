# C++ 코딩 컨벤션

베이스: C++ Core Guidelines (Bjarne Stroustrup / Herb Sutter) + C++20 표준. cpp-executor 에이전트는 코드 작성과 자체 리뷰 시 본 문서를 정본으로 참조한다.

## 1. 표준과 빌드 가정

- C++20 표준(`-std=c++20`)을 가정한다. C++17 이전으로의 약화 금지. C++23 기능은 컴파일러 지원이 충분한 경우에만.
- 컴파일러 경고 최대 가정: `-Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wnon-virtual-dtor -Wold-style-cast -Woverloaded-virtual`. `-Werror` 여부는 프로젝트 결정.
- 빌드 시스템은 CMake를 기본 가정한다(`cmake_minimum_required(VERSION 3.20)` 이상).
- 포맷터는 `clang-format`, 정적 분석은 `clang-tidy`. 양쪽 모두 CI 게이트에 들어간다는 전제.
- 호스트 환경은 POSIX 또는 Windows 모두 가능. 플랫폼 의존 코드는 격리한다.
- 의존성 정책(vcpkg/Conan/system), 표준 라이브러리 구현(libstdc++/libc++/MSVC STL), CI 게이트 구체값은 본 문서의 영역이 아니다. 프로젝트의 CLAUDE.md에서 정의된다.

## 2. 네이밍

| 종류 | 형식 | 예 |
|---|---|---|
| 변수, 함수, 멤버 함수 | snake_case | `parse_input`, `pixel_count` |
| 클래스, struct, enum 타입 | PascalCase | `HashMap`, `RenderContext` |
| 멤버 변수 (private/protected) | snake_case + `_` 접미 | `int size_;`, `Buffer buffer_;` |
| 전역 상수, constexpr | `kPascalCase` 또는 UPPER_SNAKE | `kMaxBufferSize`, `MAX_BUFFER_SIZE` |
| 매크로 | UPPER_SNAKE_CASE | `MY_LIB_LOG(...)` |
| 열거형 멤버 (enum class) | PascalCase | `enum class LogLevel { Info, Warn, Error };` |
| 템플릿 매개변수 | PascalCase | `template <typename T, std::size_t N>` |
| 네임스페이스 | snake_case | `namespace hash_map_detail { ... }` |
| 파일 | snake_case | `hash_map.hpp`, `hash_map.cpp` |
| 함수 포인터 typedef | snake_case + `_fn` 또는 `_cb` | `using compare_fn = int (*)(const T&, const T&);`, `using on_done_cb = void (*)(void*, int);` |

원칙:

- 매크로는 네임스페이스를 갖지 않으므로 **반드시 라이브러리/모듈 접두사**를 붙인다(`MY_LIB_*`). 매크로는 마지막 수단이다(§9 참조).
- 클래스 내부의 private 멤버 변수에만 `_` 접미사를 강제한다. public 데이터 멤버(POD/aggregate)는 접미사 없이 둔다.
- `enum class`만 사용한다(plain `enum` 금지). 멤버는 PascalCase로 통일(`LogLevel::Info`).
- 네임스페이스 내부 구현 디테일은 `detail`(또는 `xxx_detail`) 서브네임스페이스에 넣는다.
- 한 글자 이름은 짧은 람다, 표준 알고리즘 익숙한 관용구, 수학적 문맥에서만 허용(`i`, `j`, `x`).

## 3. 클래스, struct, enum

- **데이터만 묶고 불변식이 없으면 `struct`** (public 데이터 멤버). **불변식을 가지면 `class`** (private 데이터 + public 인터페이스).
- 멤버 초기화는 in-class 멤버 이니셜라이저를 우선 사용.

```cpp
class HashMap {
public:
    HashMap() = default;
    explicit HashMap(std::size_t initial_capacity);

    auto insert(std::string_view key, int value) -> bool;
    [[nodiscard]] auto size() const noexcept -> std::size_t { return size_; }

private:
    std::vector<Bucket> buckets_{};
    std::size_t size_{0};
};
```

- 생성자가 인자 하나면 `explicit`를 기본으로(`C.46`). 묵시 변환을 의도한 경우에만 명시적으로 빼낸다.
- 단일 인자 생성자가 아니어도 `{}` 생성 시 narrowing 의도가 없다면 `explicit` 권고.
- public 가상 함수보다 NVI(Non-Virtual Interface) 패턴 또는 `final` 클래스를 선호. 다형성이 진짜 필요할 때만 가상 함수 사용.
- 상속 시 base 클래스 소멸자는 `virtual` 또는 `protected non-virtual`. 그렇지 않으면 `final` 클래스로 상속을 차단.

### Rule of Zero / Three / Five

- **Rule of Zero 우선**: 표준 컨테이너/스마트 포인터로 리소스를 위임하면 특수 멤버 함수 5개(소멸자, 복사 ctor/대입, 이동 ctor/대입) 모두 컴파일러에 맡긴다.
- 특수 멤버 중 하나를 직접 정의/`= delete` 하면 **나머지 모두를 명시적으로 정의 또는 `= default`/`= delete`** 한다(C.21).
- 복사 비용이 큰 타입은 `= delete`로 복사 금지 + 이동만 허용을 검토.
- **PIMPL을 사용하는 클래스의 특수 멤버는 정의 위치가 `.cpp`로 강제된다.** 헤더에서 `= default`를 두면 `Impl`이 incomplete type이라 컴파일이 실패한다. PIMPL 서브섹션 참조.

```cpp
class FileHandle {
public:
    explicit FileHandle(const std::filesystem::path& path);
    ~FileHandle();

    FileHandle(const FileHandle&) = delete;
    auto operator=(const FileHandle&) -> FileHandle& = delete;

    FileHandle(FileHandle&& other) noexcept;
    auto operator=(FileHandle&& other) noexcept -> FileHandle&;

private:
    std::FILE* fp_{nullptr};
};
```

### PIMPL (불투명 구현 분리)

C의 opaque typedef 패턴(`typedef struct hash_map hash_map_t;` + 별도 `.c`의 정의)은 C++에서 PIMPL idiom으로 옮긴다. 헤더에서 내부 구현을 완전히 숨기고, 헤더 변경이 없으면 의존 번역 단위를 재컴파일하지 않게 한다.

언제 PIMPL을 도입하는가 (셋 중 하나라도 해당하면 적용 후보):

- 헤더의 ABI 안정성이 필요한 라이브러리 경계.
- 내부 데이터 구조가 자주 바뀌고 빌드 시간이 부담인 모듈.
- 무거운 의존 헤더(예: 플랫폼 SDK 헤더)를 공개 헤더에서 격리해야 하는 경우.

위 조건 어디에도 해당하지 않으면 PIMPL을 적용하지 않는다. 직접 멤버가 기본 추정값이다.

```cpp
// hash_map.hpp - 공개 헤더. 사용자는 Impl의 layout을 볼 수 없다.
class HashMap {
public:
    explicit HashMap(std::size_t initial_capacity);
    ~HashMap();

    HashMap(HashMap&&) noexcept;
    auto operator=(HashMap&&) noexcept -> HashMap&;

    auto insert(std::string_view key, int value) -> bool;
    [[nodiscard]] auto size() const noexcept -> std::size_t;

private:
    class Impl;
    std::unique_ptr<Impl> impl_;
};

// hash_map.cpp - 정의는 .cpp에만.
class HashMap::Impl {
    // 실제 layout, 의존 헤더 모두 여기에.
};

HashMap::HashMap(std::size_t initial_capacity)
    : impl_{std::make_unique<Impl>(initial_capacity)} {}

HashMap::~HashMap() = default;          // Impl 정의가 보이는 .cpp에서 정의.
HashMap::HashMap(HashMap&&) noexcept = default;
auto HashMap::operator=(HashMap&&) noexcept -> HashMap& = default;
```

주의:

- 소멸자/이동 연산은 헤더에서 `= default`로 두면 컴파일 에러가 난다(`Impl`의 incomplete type). `.cpp`에서 정의한다.
- `std::shared_ptr<Impl>`을 쓰면 incomplete type으로도 소멸 가능하지만 비용이 더 크다. 기본은 `std::unique_ptr<Impl>`.
- PIMPL은 가상 함수 호출 비용에 준하는 간접 비용이 있다. 성능 critical path에는 적용하지 않는다.
- **PIMPL은 런타임 클래스에 한한다.** `constexpr` 객체나 컴파일 타임 평가가 필요한 타입에는 적용하지 않는다. `std::unique_ptr`의 동적 할당이 `constexpr` 문맥과 양립하지 않기 때문이다.

## 4. 포인터, 참조, 소유권

- **소유권 표현은 스마트 포인터**: `std::unique_ptr<T>` 단독 소유, `std::shared_ptr<T>` 공유 소유. 공유 소유는 정말 필요할 때만.
- **raw 포인터는 비소유(non-owning) 관찰자만**. 함수 매개변수에서 "참조 + nullable" 의미일 때 사용. 그 외 비소유 참조는 `T&`/`const T&`.
- `new`/`delete` 직접 사용 금지. `std::make_unique`, `std::make_shared`, 컨테이너, 표준 알고리즘 사용.
- `T*` 매개변수가 nullable이라면 nullability를 함수 본문 진입에서 검사하거나 `std::optional<std::reference_wrapper<T>>` 사용.
- 함수 매개변수 가이드:
  - 읽기만: `T` (작고 trivially copyable), 그 외 `const T&` 또는 `std::span<const T>`/`std::string_view`.
  - 출력: 반환값 또는 `T&`. raw 포인터 출력 파라미터는 피한다.
  - 소유권 이전: `std::unique_ptr<T>` by value (이동).
- 포인터/참조 `*`, `&` 부착은 `clang-format` 설정에 위임한다(기본은 좌측 부착 `T* p`, `T& r`). 프로젝트 설정에 일관되게 따른다.

### 전역과 파일 정적 변수

- **파일 정적 심볼은 익명 네임스페이스로 격리**한다. C의 `s_` 접두사를 그대로 옮기지 않는다.

```cpp
namespace {
    int cache_hits = 0;
    constexpr std::size_t kInlineKeyMax = 64;
}
```

- **전역 변수는 가능한 회피**한다. 부득이한 경우(로깅 싱글톤, 전역 설정 등)에 한해 `g_` 접두사를 부착해 출현을 시각적으로 드러낸다.

```cpp
extern std::atomic<int> g_log_level;
```

- **출력 파라미터(`out_`)는 사용하지 않는다.** 반환값, `std::tuple`/`struct`로 묶은 반환, `T&` 참조 매개변수 중 하나로 표현한다. C 출신 코드의 `int parse(const char *s, int *out_value)` 형태는 C++에서는 `std::expected<int, ParseError> parse(std::string_view s)`로 옮긴다.

## 5. const, constexpr, noexcept

- **const는 기본**. 변경하지 않는 모든 지역/멤버 변수와 메서드를 `const`로 표시.
- 멤버 함수 중 멤버 상태를 변경하지 않는 모든 함수는 `const`. 가능한 경우 `constexpr` 추가.
- 컴파일 타임에 값이 결정되는 상수는 `constexpr` (또는 더 강한 `consteval` for 함수). `const` 단독 사용은 런타임 const 의미만.
- `noexcept`는 던지지 않음이 보장되는 함수, 특히 이동 생성자/대입에 명시(컨테이너 강한 예외 안전 제공).
- `[[nodiscard]]`는 반환값을 무시하면 버그가 되는 함수에 부착(`empty()` 같은 헷갈리는 이름, factory, status code 반환).

```cpp
[[nodiscard]] constexpr auto clamp(int value, int low, int high) noexcept -> int {
    return value < low ? low : (value > high ? high : value);
}
```

## 6. 들여쓰기, 줄, 중괄호

- 들여쓰기는 **공백 4칸**. 탭 금지. 혼용 금지.
- 100열 권고 상한. `clang-format`이 결정하면 그 설정에 따른다.
- 중괄호는 **K&R 변형(Stroustrup)**: 함수/네임스페이스/클래스의 여는 중괄호는 다음 줄, 그 외 제어문(`if`/`for`/`while`)은 같은 줄.
- 한 줄짜리 `if`도 중괄호 강제(고전적 함정 회피).
- East-const는 프로젝트 선택. 본 문서는 west-const(`const T`)를 기본으로 한다.

```cpp
if (auto it = map.find(key); it != map.end()) {
    use(it->second);
} else {
    log_miss(key);
}
```

## 7. 함수와 트레일링 반환 타입

- 함수 정의는 **트레일링 반환 타입(`auto name(...) -> T`)을 기본**으로 한다. 일반 형식과 일관되며 템플릿/람다와 자연스럽게 어울린다.
- 한 줄 짧은 정의는 `clang-format`의 결정에 따른다. 본문이 두 줄 이상이면 본문 중괄호를 다음 줄로 옮긴다.

```cpp
auto HashMap::lookup(std::string_view key) const noexcept -> const Value*
{
    // ...
}
```

- 함수는 한 가지만 하도록 작성한다. 줄 수 강제 분할 룰은 두지 않는다.
- 매개변수 5개 초과는 구조체/aggregate로 묶는 것을 검토.
- 람다 캡처는 `[&]`/`[=]` 같은 default 캡처보다 명시 캡처를 선호. 수명을 명확히 한다.

### 콜백과 함수 객체

C의 함수 포인터 typedef(`typedef int (*compare_fn)(const void *, const void *);`)는 C++에서 다음 순서로 대체한다.

1. **템플릿 매개변수**(가장 선호): 호출 측 타입을 그대로 받아 인라인. 표준 알고리즘(`std::sort`, `std::ranges::for_each`)이 이 형태.

   ```cpp
   template <typename F>
   auto for_each_active(std::span<const User> users, F&& fn) -> void {
       for (const auto& u : users) {
           if (u.is_active) { std::forward<F>(fn)(u); }
       }
   }
   ```

2. **`std::function<Sig>`**: 타입 소거가 필요한 경우(콜백 저장, 가상 디스패치 회피). 힙 할당과 간접 호출 비용이 있다.

   ```cpp
   class EventBus {
   public:
       auto subscribe(std::function<void(const Event&)> handler) -> Token;
   };
   ```

3. **`std::move_only_function<Sig>`**(C++23): 콜백이 이동 전용 캡처(`unique_ptr` 등)를 가져야 할 때.

4. **raw 함수 포인터**: C API 경계, ABI 안정성이 필요한 라이브러리 인터페이스에서 1차 허용. 성능 이유로 1~3단계에서 강등하려면 **프로파일링으로 `std::function` 간접 호출이 실제 핫스팟임을 측정한 뒤** 4단계로 이동한다. 측정 없이 "성능 우려"만으로 점프 금지. C++에서도 함수 포인터 typedef는 §2의 `_fn`/`_cb` 컨벤션을 그대로 사용한다.

   ```cpp
   extern "C" {
       using compare_fn = int (*)(const void*, const void*);
       auto bsearch(const void* key, const void* base, std::size_t n,
                    std::size_t sz, compare_fn cmp) -> void*;
   }
   ```

람다는 캡처가 없으면 함수 포인터로 묵시 변환 가능하므로 C API 콜백 등록에 직접 넘길 수 있다. 캡처가 있는 람다는 변환되지 않으므로 컨텍스트 포인터를 별도로 받는 C API 형태로 우회한다.

**멤버 함수 포인터(`&Class::method`)는 1단계 템플릿이 정답이다.** `std::function<void(Foo&)>`로 감싸 저장하는 형태도 동작하지만, 호출 시 `std::invoke`를 통해 인스턴스 + 멤버 함수 포인터를 직접 디스패치하는 편이 의도가 정직하다.

```cpp
template <typename T, typename M>
auto invoke_on(T& obj, M T::* mfn) -> decltype(auto) {
    return std::invoke(mfn, obj);
}
```

저장이 필요한 경우에만 `std::function`(2단계) 또는 `std::mem_fn`으로 감싼다.

## 8. 주석과 문서화

- **한 줄 주석 `//`만 사용.** 다중 줄 `/* */` 금지(박스 헤더, 큰 블록 주석 포함).
- WHY를 적는다. WHAT은 코드가 말한다.
- 공개 API 함수에 1~3줄 헤더 주석. Doxygen 마크업은 프로젝트 옵션(CLAUDE.md).
- TODO/FIXME에는 추적할 이름이나 이슈 번호를 붙인다(`// TODO(kms): rehash 정책 재검토`).

## 9. 리소스 관리: RAII

C와 달리 C++에서는 **`goto cleanup` 패턴을 쓰지 않는다.** RAII가 정답이다.

- 리소스는 모두 RAII 타입에 감싼다(`std::unique_ptr` with custom deleter, `std::fstream`, `std::lock_guard`, `std::scoped_lock`, 표준 컨테이너).
- 직접 RAII 클래스가 필요한 경우 §3 Rule of Zero/Five에 맞춰 작성.
- 임시 정리가 필요한 코드 블록은 scope guard 패턴 또는 `std::unique_ptr<void, Deleter>`로 처리.
- 예외 안전 보장 수준(`basic`/`strong`/`nothrow`)을 의식하고 적어도 `basic` 보장은 유지한다.

```cpp
auto load_config(const std::filesystem::path& path) -> std::expected<Config, ConfigError>
{
    std::ifstream in{path, std::ios::binary};
    if (!in) {
        return std::unexpected(ConfigError::FileNotFound);
    }

    // 파일 핸들은 std::ifstream RAII로 자동 해제.
    return parse_config(in);
}
```

## 10. 매직 넘버, constexpr, 매크로

- 매직 넘버 금지. 의미 있는 상수는 `constexpr`/`inline constexpr` 또는 `enum class`로 정의한다.
- 매크로는 **마지막 수단**. 가능한 모든 곳에서 `constexpr` 함수, `inline constexpr` 변수, `template`, `consteval`로 대체.
- 매크로가 불가피하면 라이브러리 접두사 + `do { } while (0)` 또는 `((void)0)` 형식으로 작성.

```cpp
inline constexpr std::size_t kMaxBufferSize = 4096;

enum class LogLevel { Info, Warn, Error };

template <typename T, std::size_t N>
[[nodiscard]] constexpr auto array_size(const T (&)[N]) noexcept -> std::size_t {
    return N;
}
```

## 11. 정수, 부동소수, 타입 추론

- 카운트/인덱스: `std::size_t` 또는 `std::ptrdiff_t`. 컨테이너 인덱스 부호 변환 경고가 거슬리면 `ssize_t` 헬퍼나 명시 cast로 의도를 드러낸다.
- 폭이 본질인 경우만 `<cstdint>` (와이어 포맷, 비트 마스크, 픽셀/오디오 샘플 등).
- 일반 카운터를 모두 `uint32_t`로 통일하지 않는다. 의도 신호가 사라진다.
- `auto` 사용 기준:
  - 우변 타입이 길고 좌변에 반복되면 `auto` 권고(`auto it = map.begin();`).
  - 반환 타입이 `std::expected<T, E>` 등 길면 `auto` 또는 `auto&&`로 받아 가독성 확보.
  - 단순/즉시 자명한 타입은 명시(`int count = 0;`).
- `auto&&`는 universal reference 의미를 의식하고 사용. 그 외 const 참조로 받을지 값으로 받을지 의도적으로 결정.
- 부호/폭 변환은 `static_cast`로 명시. `(int)x` 같은 C-style cast 금지. `reinterpret_cast`/`const_cast`는 정말 필요한 곳에만.

## 12. 표준 라이브러리, range, 알고리즘

- **표준 라이브러리 우선**. 직접 자료구조/알고리즘을 구현하기 전에 STL이 답을 가지고 있는지 확인.
- C++20 `<ranges>`를 적극 활용. `std::ranges::sort(v)` `std::views::filter` 등으로 가독성 확보.
- `std::string_view`, `std::span<T>`로 비소유 뷰를 표현. `const std::string&` 매개변수보다 `std::string_view`가 일반적으로 우월.
- 컨테이너 선택:
  - 기본: `std::vector<T>`. 캐시 친화적.
  - 키 기반 조회: `std::unordered_map`(평균 O(1)) > `std::map`(정렬 필요할 때).
  - 작은 컬렉션: small-vector 같은 사용자 정의가 필요할 정도면 그때 도입.
- `auto&` 또는 `const auto&` 범위 기반 for를 사용해 복사 비용 차단:

```cpp
for (const auto& item : items) {
    process(item);
}
```

## 13. 에러 처리: 예외, std::expected, std::optional

- **예외**는 프로그램 invariants 위반이나 복구 가능한 시스템 오류(파일 I/O, 네트워크)에 사용. 생성자가 실패할 수 있으면 예외.
- **`std::expected<T, E>`**(C++23) 또는 프로젝트 자체 `Result<T, E>`로 예측되는 도메인 에러 표현. 예외 비활성 환경(임베디드, 게임, 일부 라이브러리)에서 표준.
- **`std::optional<T>`**는 "값이 없을 수 있다"는 의미만 표현. 에러 원인까지 전달해야 하면 expected 사용.
- 예외 사용 시:
  - 던지는 함수는 `noexcept` 없음을 명시. `noexcept(false)`는 가독성용 어노테이션으로만.
  - `catch (const std::exception& e)`로 base 참조 캐치. catch-all `catch (...)`는 최상위에서만.
  - 소멸자에서 던지지 않는다. 던지면 `std::terminate`.
- 예외와 expected 중 선택은 프로젝트 컨벤션(CLAUDE.md). 한 프로젝트 내에서 일관성을 유지한다.

## 14. 헤더와 모듈 구조

- 헤더 한 개당 모듈/논리 단위 한 개. `module/foo.hpp` ↔ `module/foo.cpp`.
- 헤더 가드는 `#pragma once`를 기본으로 한다. 미지원 컴파일러 대응이 필요하면 `PROJECT_MODULE_FOO_HPP` 형식 include guard.
- 헤더는 자체 포함 가능해야 한다. 필요한 의존 헤더를 자체 `#include`로 가져온다(IWYU 원칙).
- `using namespace` 디렉티브는 **헤더에서 금지**. `.cpp` 내부의 좁은 스코프에서만 허용.
- 헤더 정렬: ① 대응 `.cpp`의 짝 헤더(`foo.cpp`의 `foo.hpp`) → ② C++ 표준 → ③ C 표준 → ④ 외부 라이브러리 → ⑤ 프로젝트 내부. 각 그룹 사이 빈 줄.
- 템플릿 정의는 헤더에 두거나 `.tpp`/`.inl` 분리 후 헤더 끝에서 include.
- C++20 modules 사용은 프로젝트 정책(빌드 시스템 성숙도 확인 필요).
- 내부 헬퍼는 익명 네임스페이스(`namespace { ... }`)에 둔다. 외부 노출 의도가 없는 심볼이 링크 단계에서 새지 않게 한다.

### `extern "C"` ABI 경계

C 호출 규약으로 노출되는 인터페이스는 C 컨벤션을 따른다(`c.md` §2 참조).

- 함수/변수 이름은 `snake_case` + 라이브러리 접두사(`my_lib_init`, `my_lib_release`).
- opaque 핸들은 `_t` 접미사 typedef(`typedef struct my_lib_ctx my_lib_ctx_t;`).
- 상수는 `UPPER_SNAKE_CASE` + 라이브러리 접두사.
- 함수 포인터 typedef는 `_fn`/`_cb` 접미사.

C++ 구현 측은 cpp.md 컨벤션을 따르되, 헤더의 `extern "C"` 블록 안쪽만 C 컨벤션으로 표기한다.

```cpp
// my_lib.h - C/C++ 모두 include 가능한 ABI 헤더.
#ifdef __cplusplus
extern "C" {
#endif

typedef struct my_lib_ctx my_lib_ctx_t;
typedef void (*my_lib_log_cb)(int level, const char* msg, void* user_data);

auto my_lib_init(my_lib_ctx_t** out_ctx) -> int;
auto my_lib_release(my_lib_ctx_t* ctx) -> void;

#ifdef __cplusplus
}
#endif
```

내부 구현(`my_lib.cpp`)은 C++ 클래스/PIMPL/RAII로 자유롭게 작성. 경계 함수에서 `my_lib_ctx_t*`를 내부 C++ 객체로 캐스팅한다. 예외는 ABI 경계를 넘기지 않는다(C++ 예외는 C에서 처리 불가, 무조건 catch 후 에러 코드로 변환).

## 15. UB와 안전

코드 작성 직후 명시적으로 점검할 항목.

- **초기화되지 않은 자동 변수 읽기 금지.** 모든 자동 변수는 선언 시 초기화(`int n{0};`).
- **dangling reference/pointer**: 임시 객체의 참조 캡처(특히 `auto&& x = f().g();`에서 `f()` 임시 소멸), 컨테이너 변경 후 이터레이터 무효화.
- **narrowing**: `int → short`, `size_t → int` 등 좁히는 변환은 명시적 cast 또는 `gsl::narrow`로 드러낸다. `{}` 초기화는 narrowing을 막아준다.
- **부호 변환**: signed ↔ unsigned 묵시 변환에 `-Wconversion` 경고가 나면 의도를 드러내거나 타입을 재설계.
- **정수 오버플로**: `size_t` 곱셈에 주의. C++20에서는 `<numeric>`의 saturate_cast/체크 헬퍼 또는 `__builtin_*_overflow` 등 컴파일러 내장 사용.
- **strict aliasing**: 비트 표현 재해석은 `std::bit_cast`(C++20) 또는 `std::memcpy`. `reinterpret_cast` 후 역참조는 UB 위험.
- **iterator 무효화**: `std::vector::push_back`, `std::map::erase` 같은 변경 호출 후 이전 이터레이터 사용 금지.
- **lifetime**: 람다가 외부 지역 변수를 참조 캡처 후 람다가 그 지역을 벗어나서 호출되는 경우, 콜백 등록 함수에서 흔히 발생.
- **null 역참조**: 외부에서 받은 raw 포인터는 함수 진입 게이트에서 점검. `std::optional`/`reference_wrapper`로 nullable 의미를 타입에 인코딩.
- **format 보안**: `std::format` 사용 시 사용자 입력을 형식 문자열로 받지 않는다(`std::format("{}", user_input)`만 허용).
- **데이터 경쟁**: 멀티스레드에서 공유 가변 상태는 `std::mutex`, `std::atomic` 또는 메시지 패싱으로만 접근.

검출 도구는 ASan, UBSan, TSan, `clang-tidy`, `cppcheck`를 기본 가정으로 둔다. 활성화 여부는 CLAUDE.md.

## 16. clang-format / clang-tidy 정합

- 본 문서의 포맷 규칙은 `clang-format`이 강제할 수 있도록 작성되었다. 프로젝트 `.clang-format`이 본 문서와 다르면 프로젝트 설정이 우선이며, 본 문서의 시각적 규칙(들여쓰기, 중괄호, 열 폭)을 무시할 수 있다.
- `clang-tidy` 체크는 `modernize-*`, `cppcoreguidelines-*`, `performance-*`, `readability-*` 그룹을 기본 가정. 구체 활성화 목록은 프로젝트 `.clang-tidy`에서 정의.
- cpp-executor는 코드 작성 후 `clang-format`/`clang-tidy` 실행을 가정하지만 실제 실행은 사용자 또는 CI가 수행한다. 작성 단계에서는 본 문서 체크리스트로 사전 점검.

## 17. 자체 리뷰 체크리스트

cpp-executor는 코드 생성 직후 본 목록을 모두 점검한다.

- [ ] 네이밍이 §2 준수. 매크로에 라이브러리 접두사. private 멤버에 `_` 접미사.
- [ ] `enum class`만 사용. plain `enum` 없음.
- [ ] Rule of Zero 우선. 특수 멤버 5개 중 하나라도 정의 시 나머지 명시(C.21).
- [ ] `new`/`delete` 직접 사용 없음. 소유는 `unique_ptr`/`shared_ptr` 또는 컨테이너.
- [ ] raw 포인터는 비소유 의미만. 소유권은 스마트 포인터로 명시.
- [ ] 파일 정적 심볼은 익명 네임스페이스. 전역 변수는 회피, 부득이한 경우만 `g_` 접두사. `out_` 출력 파라미터 없음.
- [ ] 라이브러리 ABI 경계나 무거운 의존을 가진 헤더는 PIMPL(`unique_ptr<Impl>`) 적용 검토. PIMPL 클래스의 소멸자/이동 연산은 `.cpp`에서 정의(헤더 `= default` 금지).
- [ ] 콜백은 템플릿 → `std::function` → 함수 포인터 순으로 선택. C API 경계만 raw 함수 포인터.
- [ ] `const`/`constexpr`/`noexcept`/`[[nodiscard]]` 가능한 곳에 부착.
- [ ] 단일 인자 생성자에 `explicit` 부착(의도적 묵시 변환 제외).
- [ ] 들여쓰기 공백 4칸. 한 줄 if도 중괄호 부착.
- [ ] 트레일링 반환 타입(`auto f(...) -> T`)을 함수 정의에 적용.
- [ ] `/* */` 다중 줄 주석/박스 헤더 없음. `//` 단일 줄만.
- [ ] RAII로 리소스 관리. `goto cleanup` 패턴 없음.
- [ ] 매직 넘버 없음. `constexpr` 또는 `enum class`로 명명.
- [ ] 매크로는 마지막 수단이며 라이브러리 접두사 부착.
- [ ] `using namespace` 헤더 사용 없음. `.cpp` 좁은 스코프에서만.
- [ ] 헤더 자체 포함성 + IWYU. 익명 네임스페이스로 내부 헬퍼 격리.
- [ ] §13 에러 처리 방식이 프로젝트 컨벤션과 일치(예외 vs `std::expected`).
- [ ] §15 UB 잠재 위치 점검(초기화, narrowing, dangling, 이터레이터 무효화, lifetime).
- [ ] C-style cast(`(T)x`) 없음. `static_cast`/`std::bit_cast`/`std::memcpy` 사용.
- [ ] 함수가 한 가지만 한다.
- [ ] 프로젝트 기존 패턴과 일관성.

## 18. 본 문서가 다루지 않는 것

다음은 본 문서의 영역이 아니다. 프로젝트의 CLAUDE.md에서 정의된다.

- 구체적 컴파일러 종류와 버전, 표준 라이브러리 구현(libstdc++/libc++/MSVC STL) 선택.
- 의존성 관리 도구(vcpkg, Conan, system) 선택.
- 테스트 프레임워크(GoogleTest, Catch2, doctest) 선택과 CI 게이트.
- 정적 분석/sanitizer 활성화 옵션 구체값.
- 예외 정책(예외 허용 vs `-fno-exceptions`).
- RTTI 정책, `-fno-rtti` 사용 여부.
- C++20 modules 사용 여부.
- Doxygen 등 문서화 도구 사용 여부.

cpp-executor는 위 결정을 가정으로 받아 코드 작성과 자체 리뷰에만 집중한다.
