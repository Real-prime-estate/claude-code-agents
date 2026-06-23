# SwiftUI 디자인 컨벤션

베이스: Apple HIG, SwiftUI 관용구, iOS 17+ 현대 패턴. swiftui-designer-executor는 View 레이어 작성과 자체 디자인 리뷰 시 본 문서를 정본으로 참조한다. 일반 Swift 규칙(네이밍, 옵셔널, Concurrency)은 `swift.md`에서 다루므로 함께 Read한다.

## 1. 디자인 토큰

색상, 폰트, 간격은 토큰화한다. 토큰이 프로젝트에 이미 있으면(`Theme.swift`, `Color+Extensions.swift` 등) 재사용. 없으면 최소한의 토큰을 도입한다.

- 색상 토큰: 의미론적 이름(`background`, `accent`, `danger`). 고정 RGB는 브랜드 색상에 한해서만.
- 폰트 토큰: `Font` extension으로 디자인의 의미론(`titleEmphasized`, `bodySecondary`) 표현. 시스템 폰트 스타일이 1차 빌딩 블록.
- 간격 토큰: 4pt 그리드 기반 enum/상수(`Spacing.xs = 4`, `Spacing.sm = 8`, `Spacing.md = 16` 등).

```swift
extension Color {
    static let appBackground = Color(.systemBackground)
    static let appAccent = Color("AccentColor", bundle: .main)
}
```

## 2. 의미론적 색상

- `Color.black`, `Color.white` 직접 사용 금지. Dark Mode에서 깨진다.
- 시스템 의미론 색상 우선: `Color(.systemBackground)`, `Color(.label)`, `Color(.secondaryLabel)`, `Color(.separator)`, `Color(.systemGroupedBackground)`.
- 브랜드 색상은 Asset Catalog에 Light/Dark variant를 모두 등록.
- `.primary` / `.secondary` foreground는 텍스트의 의미적 위계에 맞춘다.

## 3. 시스템 폰트와 Dynamic Type

- 폰트 크기는 의미론 스타일(`.largeTitle`, `.title`, `.headline`, `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption`)로 지정.
- `.font(.system(size: 17))` 같은 절대 크기 금지. Dynamic Type 대응이 깨진다.
- 무게/디자인이 필요하면 `.font(.body.weight(.semibold))` 또는 `.fontDesign(.rounded)` 모디파이어.
- 한 View의 텍스트가 XXL 사이즈에서도 레이아웃이 살아남는지 Preview로 확인.

## 4. 4pt 그리드

`spacing`, `padding`, `cornerRadius`, frame 크기는 4의 배수.

- 권장값: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64.
- 7, 13, 19 같은 비그리드 값 금지.
- 다이얼로그, 셀, 카드 padding은 16 또는 20을 기본으로 두고 위계에 따라 단계적으로 조정.

```swift
VStack(spacing: 12) {
    Text(title).font(.headline)
    Text(body).font(.body)
}
.padding(16)
```

## 5. 터치 타겟

탭 가능한 영역은 최소 44×44pt. 시각 요소는 작더라도 hit area를 키운다.

```swift
Button(action: tap) {
    Image(systemName: "xmark")
        .frame(width: 44, height: 44)
}
```

`.contentShape(Rectangle())`로 투명 영역까지 탭이 잡히게 한다.

## 6. SF Symbols

아이콘은 `Image(systemName:)` 우선. 일관성, Dark Mode, Dynamic Type, 접근성을 모두 자동으로 얻는다.

- 커스텀 이미지는 브랜드 로고, 일러스트 등 SF Symbols로 대체 불가한 경우에만.
- 심볼 변형은 `.symbolRenderingMode(.hierarchical | .palette | .multicolor)`로 의미적 강조를 결정.
- 심볼 애니메이션은 `.symbolEffect(.pulse)`, `.symbolEffect(.bounce)` (iOS 17+).
- 아이콘만으로 의미를 전달할 때 `accessibilityLabel`을 반드시 제공.

## 7. Dark Mode

- 모든 컬러/에셋이 Dark Mode에서 자동 대응되는지 확인.
- Asset Catalog 색상은 Any/Dark variant 등록.
- Preview에 `.preferredColorScheme(.dark)` variant 항상 포함.
- 이미지 위 텍스트는 `Material` 배경(`ultraThinMaterial`, `thinMaterial`)으로 가독성 확보.

## 8. 접근성

- 의미 있는 이미지는 `accessibilityLabel`을 제공.
- 장식 이미지는 `accessibilityHidden(true)`.
- 중요한 인터랙션에 `accessibilityHint`로 행동 결과를 설명.
- 색상만으로 정보를 전달하지 않는다. 텍스트, 아이콘, 형태로 중복 신호.
- 같은 의미를 가진 작은 컴포넌트가 흩어져 있다면 `accessibilityElement(children: .combine)`로 단일 노드로 합친다.
- 부모에 단일 레이블을 주고 자식은 무시하려면 `.accessibilityElement(children: .ignore)` + 부모에 `accessibilityLabel`.
- 동적 콘텐츠(로딩, 갱신)는 `.accessibilityAddTraits(.updatesFrequently)`로 사용자에게 알린다.

## 9. 애니메이션

- 명시적 `withAnimation { ... }` 또는 `.animation(_, value:)`. 묵시적 애니메이션 회피.
- 공유 transition은 `matchedGeometryEffect(id:in:)`.
- 시퀀스가 복잡하면 `PhaseAnimator`(iOS 17+) 또는 `KeyframeAnimator`.
- Reduce Motion 대응: `@Environment(\.accessibilityReduceMotion)`로 분기 또는 애니메이션 비활성.
- 스프링은 `.spring(response: , dampingFraction:)`로 의도 명시. 모든 애니메이션을 `.easeInOut`으로 통일하지 않는다.

```swift
withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
    isExpanded.toggle()
}
```

## 10. View 구조

- 한 View body는 40줄 이내를 권장. 그 이상이면 자식 View로 분해.
- 반복 컴포넌트는 별도 `struct ItemRow: View`로 추출하고 `ForEach`로 사용.
- 재사용 가능한 스타일은 `ViewModifier`. `extension View`로 모디파이어 함수 형태 노출.
- `@ViewBuilder`를 활용해 조건 분기 깔끔하게.

```swift
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}
```

## 11. 상태와 데이터

- `@State` 범위는 최소화. View 안에서만 의미가 있는 상태에 한정.
- 부모-자식 공유는 `@Binding`. 부모가 ownership.
- ViewModel은 `@Observable` 매크로(iOS 17+) 또는 `@StateObject`/`ObservableObject`. 신규 코드는 `@Observable` 권장.
- 환경 주입은 `@Environment` 또는 `EnvironmentValues` 확장.
- `@MainActor` 명시(ViewModel, View).

## 12. 성능

- 리스트 같은 다수 요소는 `LazyVStack`, `LazyHStack`, `LazyVGrid`.
- View body에서 무거운 계산 금지. 사전 계산 또는 `Task`로 분리.
- `id:`를 안정적으로 부여. 인덱스 사용은 회피하고 도메인 ID를 사용한다.
- 자주 갱신되는 작은 영역은 별도 자식 View로 격리해 SwiftUI의 무효화 범위를 좁힌다.

## 13. Preview

모든 View에 `#Preview`를 제공한다. 최소 Light/Dark + 큰 Dynamic Type variant.

```swift
#Preview("Light") {
    ProfileView(user: .sample)
}

#Preview("Dark") {
    ProfileView(user: .sample)
        .preferredColorScheme(.dark)
}

#Preview("XXL") {
    ProfileView(user: .sample)
        .dynamicTypeSize(.xxxLarge)
}
```

목 데이터(`.sample`)는 도메인 타입에 `static var sample: Self` 컨벤션으로 마련해 두면 재사용성이 좋다.

## 14. iOS 17+ 현대 패턴

- `@Observable` 매크로(Observation 프레임워크): `@StateObject`/`@ObservedObject`보다 선호.
- `NavigationStack` / `NavigationSplitView`: 신규 내비게이션. `NavigationView` 신규 사용 금지.
- `ContentUnavailableView`: 빈 상태 표시.
- `ScrollView` + `.scrollTargetBehavior(.viewAligned)`: 페이징 스크롤.
- `.symbolEffect`: SF Symbol 애니메이션.
- `Inspector`: 사이드 패널.

최소 iOS 버전이 위 API 미만이면 `if #available`로 분기 또는 fallback 경로 제공.

## 15. 금지 사항 요약

- 고정 RGB 색상 남발(브랜드 외).
- `Color.black`, `Color.white` 직접 사용.
- `.font(.system(size: ...))` 절대 크기.
- 비그리드 spacing 값(7, 13, 19 등).
- VoiceOver 레이블 누락.
- Preview 없이 제출.
- `!` force unwrap.
- `self.` 과용.

## 16. 자체 리뷰 체크리스트

swiftui-designer-executor는 코드 생성 직후 본 목록을 모두 점검한다.

**의미론**
- [ ] 고정 RGB 없음(브랜드 제외). `Color.black`/`Color.white` 직접 사용 없음.
- [ ] 시스템 폰트 스타일 사용. 절대 크기 없음.
- [ ] 4pt 그리드 준수.

**반응성**
- [ ] Dark Mode Preview 확인.
- [ ] Dynamic Type XXL Preview 확인.
- [ ] 필요 시 landscape/compact 대응 확인.

**접근성**
- [ ] 터치 타겟 44×44pt 이상.
- [ ] 의미 이미지에 `accessibilityLabel`.
- [ ] 장식 요소는 `accessibilityHidden(true)`.
- [ ] 중요 인터랙션에 `accessibilityHint`.
- [ ] 색상만으로 정보 전달하지 않음.

**성능**
- [ ] 리스트에 `LazyVStack`/`LazyHStack`/`LazyVGrid` 사용.
- [ ] body 내 heavy 계산 없음.
- [ ] `@State` 범위 최소.

**SwiftUI 관용구**
- [ ] `self.` 최소 사용.
- [ ] `@ViewBuilder` 활용.
- [ ] `ViewModifier`로 재사용 스타일 추출.
- [ ] `!` force unwrap 없음.

**Preview**
- [ ] Light/Dark/XXL variant 제공.

## 17. 본 문서가 다루지 않는 것

다음은 본 문서의 영역이 아니다. 프로젝트의 CLAUDE.md에서 정의된다.

- 최소 iOS 타깃과 디바이스 범위.
- 디자인 시스템 정식 명칭, 브랜드 색상 구체값.
- 네비게이션 라우팅 라이브러리 선택.
- 분석/로깅 SDK 연동.
- 스냅샷 테스트 도구 선택.

일반 Swift 규칙(네이밍, 옵셔널 처리, Concurrency)은 `swift.md`에 있으며 swiftui-designer-executor는 그 문서도 함께 Read한다.
