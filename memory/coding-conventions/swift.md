# Swift 코딩 컨벤션

베이스: Swift 6.0+, Apple API Design Guidelines, Swift Concurrency. swift-executor와 swiftui-designer-executor가 코드 작성과 자체 리뷰 시 본 문서를 정본으로 참조한다. swiftui-designer-executor는 본 문서에 더해 `swiftui.md`도 함께 참조한다.

## 1. 표준과 빌드 가정

- Swift 6.0 이상을 가정. strict concurrency checking 활성화 가정.
- 컴파일러 경고는 가능한 모두 켠다. 구체 옵션값은 CLAUDE.md.
- Swift Concurrency(`async`/`await`, `actor`, `Sendable`) 전면 채택. completion handler 기반 신규 API는 작성하지 않는다.
- 패키지 관리자(SPM vs CocoaPods), 최소 OS 타깃, 모듈 분할 규칙은 본 문서의 영역이 아니다. 프로젝트의 CLAUDE.md에서 정의된다.

## 2. Apple API Design Guidelines

원칙: **명확성이 간결성보다 우선한다.** 짧지만 모호한 이름보다 약간 길어도 사용 시점에서 의미가 분명한 이름을 선호한다.

호출부에서 자연스럽게 영어 문장처럼 읽히는 argument label을 사용한다.

```swift
// 권장
list.insert(newItem, at: 0)
employees.remove(at: position)
items.append(contentsOf: others)

// 비권장
list.insert(0, newItem)        // 의미 모호
employees.remove(position)     // 인자가 무엇인지 불명
```

argument label과 매개변수 이름은 다를 수 있다. 호출부 가독성을 위해 label을 별도로 둔다.

```swift
func move(from source: Index, to destination: Index)
```

## 3. 네이밍

| 종류 | 형식 | 예 |
|---|---|---|
| 변수, 함수, 메서드 | camelCase | `userCount`, `fetchProfile` |
| 타입(struct/class/enum/protocol) | PascalCase | `UserRepository`, `Cancellable` |
| 케이스(enum case) | camelCase | `case loaded(User)`, `case failed(Error)` |
| 제네릭 매개변수 | PascalCase 짧게 | `T`, `Element`, `Key`, `Value` |

boolean 프로퍼티/함수는 `is`, `has`, `can`, `should` 접두사.

```swift
var isAuthenticated: Bool { get }
func canRetry(after error: Error) -> Bool
```

프로토콜은 두 가지 양식.

- 능력(capability)을 표현하면 `-able`, `-ible` 접미사. `Codable`, `Cancellable`, `Comparable`.
- 역할(role)을 표현하면 명사. `Collection`, `IteratorProtocol`, `View`.

## 4. struct 우선

기본은 `struct`. `class`는 다음 중 하나가 필요할 때만 선택한다.

- 참조 시맨틱이 필요(공유 상태, 동일성 비교가 의미 있음).
- 상속이나 `deinit`이 필요.
- Objective-C와의 상호 운용에서 강제됨.
- 비용 큰 인스턴스의 복사를 회피해야 함.

class를 선택하면 코드 내에서 그 사유를 분명히 한다. 단순 데이터 묶음은 `struct`로 충분하다.

`final class`를 기본으로 두고, 상속 의도가 분명할 때만 `open` 또는 `public non-final`로 노출한다.

## 5. 옵셔널 안전성

- **force unwrap `!` 금지.** 외부 입력, IBOutlet을 포함해 어떤 경우에도 사용하지 않는다.
- `guard let`, `if let`, `??`, `?.`을 사용해 안전하게 해제한다.
- implicit unwrapped optional(`T!`)은 IBOutlet처럼 초기화 후 즉시 채워지는 매우 좁은 경우에만.
- `try!`와 `as!`도 동일하게 금지. 캐스트는 `as?` 사용 후 분기한다.

```swift
guard let user = currentUser else { return }
let name = user.displayName ?? "guest"
```

`fatalError`는 정말 도달 불가능한 분기(예: switch의 절대 안 들어오는 case)에만, 그 이유를 메시지로 남긴다.

## 6. self 최소 사용

`self`는 컴파일러가 요구할 때만 쓴다.

- 클로저 안에서 캡처를 분명히 할 때.
- 매개변수 이름과 프로퍼티 이름이 충돌할 때.
- `init` 안에서 위 두 경우.

그 외에는 생략한다. `self.`로 모든 프로퍼티를 두르는 스타일은 가독성을 해친다.

```swift
struct UserView: View {
    let user: User
    var body: some View {
        Text(user.displayName)   // self.user 아님
    }
}
```

## 7. 코드 스타일

- 들여쓰기 4 스페이스. 탭 금지.
- 줄 길이 100자.
- trailing comma는 다중 인자 호출/배열 리터럴에서 허용. 단일 인자에는 사용하지 않는다.
- one-liner는 expression-body return 생략 가능: `var x: Int { 42 }`.
- access control은 의도가 가장 좁게 드러나도록 명시한다. 기본 `internal`을 의도하더라도 `public`/`private`을 의식적으로 표기.
- `private(set)`로 외부 read-only 의도 표현.

## 8. 에러 처리

- Swift `throws`를 1차 도구로 사용. 결과 타입을 직접 반환할 필요가 있는 비동기 경계에서는 `Result<T, E>`.
- 도메인 에러는 `enum: Error`로 정의. case 단위로 의미가 분명하게.
- `catch`는 구체 패턴 매칭. 모두 받는 `catch { }`는 진입점이나 최종 핸들러에서만.
- 외부 라이브러리에서 던진 에러를 도메인 에러로 변환하는 경계를 분명히 둔다.

```swift
enum ProfileError: Error {
    case notFound(UserId)
    case unauthorized
}
```

## 9. Swift Concurrency

- 비동기 API는 `async`로 표현. completion handler 기반 신규 API는 작성하지 않는다.
- 공유 가변 상태는 `actor`로 격리. 외부에서는 `await`로 접근.
- 값 타입은 자동 `Sendable`을 만족하도록 작성한다. 참조 타입을 actor 외부로 전달해야 하면 `@unchecked Sendable` 부여 시 사유 주석을 남긴다.
- `Task` 생명주기를 분명히 한다. 도망 태스크 금지. 부모 scope에 묶인 `async let` 또는 `withTaskGroup`을 사용한다.
- `@MainActor` 격리는 UI 진입점(View, ViewModel)에 명시한다.

```swift
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: Profile?

    func load(id: UserId) async {
        profile = try? await api.fetchProfile(id)
    }
}
```

## 10. 프로토콜과 generic

- 능력 프로토콜은 가능하면 작게 정의한다(single responsibility).
- 프로토콜 default implementation은 `extension Protocol where ...`에서. 동작이 갈리는 경우 documentation으로 분명히.
- generic where 절은 가독성 위해 여러 줄로 분할.
- existential `any`와 generic `some`을 의식적으로 구분한다.
  - 단일 구체 타입의 추상화에는 `some Protocol` 권장.
  - 컬렉션 같은 다중 보관이 필요하면 `any Protocol`.

## 11. 자체 리뷰 체크리스트

swift-executor는 코드 생성 직후 본 목록을 모두 점검한다.

- [ ] 네이밍 §3 준수. 프로토콜은 능력 `-able`/`-ible` 또는 역할 명사.
- [ ] argument label로 호출부가 자연스럽게 읽힘.
- [ ] `struct` 우선. `class` 사용 시 사유 분명.
- [ ] `final class` 기본. 상속 의도만 `open`/`public non-final`.
- [ ] `!` force unwrap 없음. `try!` / `as!` 없음.
- [ ] `self` 최소 사용.
- [ ] 4 스페이스, 100자.
- [ ] access control 명시. 가장 좁게.
- [ ] `throws` 또는 `Result` 일관 사용. 모두 받는 `catch` 없음.
- [ ] `async`/`await` + `actor` + `Sendable` 일관.
- [ ] `@MainActor` 격리가 UI 경로에 명시.
- [ ] 프로젝트 기존 패턴과 일관성.

## 12. 본 문서가 다루지 않는 것

다음은 본 문서의 영역이 아니다. 프로젝트의 CLAUDE.md에서 정의된다.

- 패키지 관리자(SPM vs CocoaPods vs Carthage) 선택.
- 최소 OS 타깃과 deployment target.
- 라이브러리 의존성 정책.
- 테스트 프레임워크(XCTest vs Swift Testing) 선택.
- CI 옵션과 빌드 구성.

swift-executor는 위 결정을 가정으로 받아 코드 작성과 자체 리뷰에만 집중한다. SwiftUI View 레이어의 디자인 토큰, 접근성, 애니메이션은 본 문서가 아니라 `swiftui.md`에서 다룬다.
