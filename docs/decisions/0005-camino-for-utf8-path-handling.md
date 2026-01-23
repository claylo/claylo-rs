---
status: accepted
date: 2026-01-04
---

# Camino for UTF-8 Path Handling

## Context and Problem Statement

Rust's standard library `PathBuf` and `Path` types handle arbitrary byte sequences, not just valid UTF-8. This is correct for maximum compatibility but makes string operations verbose. Should the template use standard paths or a UTF-8 path library?

## Decision Drivers

* Configuration file paths will be displayed to users (error messages, logging)
* Config values may contain paths that need string manipulation
* Future-proofing: unknown where the application will run
* Developer ergonomics for common path operations
* Avoiding runtime panics from invalid UTF-8 paths

## Considered Options

* Standard library `PathBuf`/`Path`
* `camino` crate (`Utf8PathBuf`/`Utf8Path`)
* String-based paths

## Decision Outcome

Chosen option: "camino crate", because it provides UTF-8 guarantees at the type level, eliminating a class of potential bugs while improving ergonomics for string operations.

### Consequences

* Good, because path-to-string conversion is infallible (no `.to_string_lossy()`)
* Good, because `Display` implementation works naturally for error messages
* Good, because string operations (contains, replace, etc.) work directly
* Good, because type system prevents accidentally mixing UTF-8 and non-UTF-8 paths
* Neutral, because adds a dependency
* Bad, because paths from external sources must be validated/converted

### Confirmation

The choice is confirmed by:
- Config paths display cleanly in error messages
- No `.to_string_lossy()` or `.to_str().unwrap()` calls needed
- Path operations in config discovery are straightforward

## Pros and Cons of the Options

### Standard library PathBuf/Path

* Good, because no additional dependency
* Good, because handles all possible filesystem paths
* Bad, because string conversion is fallible
* Bad, because `.to_string_lossy()` may silently corrupt paths
* Bad, because verbose for common operations

### camino crate (Utf8PathBuf/Utf8Path)

* Good, because UTF-8 guarantee at type level
* Good, because infallible string conversion
* Good, because ergonomic for display and manipulation
* Neutral, because small, well-maintained dependency
* Bad, because external paths need conversion
* Bad, because rejects valid non-UTF-8 paths

### String-based paths

* Good, because simple string operations
* Bad, because loses path semantics (separators, components)
* Bad, because easy to create invalid paths
* Bad, because not idiomatic Rust

## More Information

Camino is widely used in the Rust ecosystem, including by:
- cargo (for internal path handling)
- rust-analyzer
- Many CLI tools

The crate provides `Utf8PathBuf` and `Utf8Path` as drop-in replacements for `PathBuf` and `Path`, with the added guarantee that contents are valid UTF-8.

Converting from standard paths:
```rust
use camino::Utf8PathBuf;

// From std::path::PathBuf - returns Result
let utf8_path = Utf8PathBuf::from_path_buf(std_path)?;

// Or try_from
let utf8_path = Utf8PathBuf::try_from(std_path)?;
```
