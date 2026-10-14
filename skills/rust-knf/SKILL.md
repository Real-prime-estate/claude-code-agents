---
name: rust-knf
description: 이 사용자의 Rust 코딩 규약(BSD KNF C 개발자가 읽히는 Rust, 2026-10-08 확정). Rust 코드를 쓰거나 고치거나 리뷰할 때, Cargo 워크스페이스·rustfmt·clippy 설정을 만들 때, "rust 규약", "rust 컨벤션", "rust 코드 짜줘", "rust 리뷰" 같은 요청에 쓴다.
---

# rust-knf

이 사용자의 Rust 코드는 아래 규약을 따른다. 원칙은 "문법은 최대한 명시적으로"다.

1. 먼저 이 플러그인 안의 `memory/coding-conventions/rust.md`(`${CLAUDE_PLUGIN_ROOT}/memory/coding-conventions/rust.md`)를 Read한다. 14개 절과 검증된 예제, 리뷰 체크리스트가 정본이다.
(`${CLAUDE_PLUGIN_ROOT}`는 플러그인 루트다. 치환되지 않았으면 `~/.claude/plugins/cache/**/claude-code-agents/*/memory/coding-conventions/` 아래 같은 파일 이름을 Glob으로 찾아 가장 높은 버전을 읽는다.)
2. 규모 있는 작성·수정은 이 플러그인의 `rust-executor` 에이전트에 맡긴다. 작은 수정은 직접 하되 같은 규약과 체크리스트를 지킨다.
3. 새 워크스페이스를 만들 때는 규약 §1의 `[lints]`·`[profile.release]`, `clippy.toml`, §5의 `rustfmt.toml`을 그대로 넣는다.
4. 게이트는 `cargo fmt --check` → `cargo clippy --all-targets` → `cargo test`이고, 도구가 못 잡는 규칙(단위 함수 `return;`, 메서드 문법 금지, 선두 선언 등)은 체크리스트로 확인한다.
