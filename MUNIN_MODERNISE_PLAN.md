# Munin Swift 6 Modernization Plan

> **Status:** In progress on branch `modernize-swift6`. This document is committed
> as the first commit and removed in the final commit of the branch. Deferred
> work is captured in `FUTURES.md` before removal.

## Objective

Modernize Munin from Swift 5.8 to Swift 6.3.1 with:

1. Strict concurrency compliance (no `@unchecked Sendable` escapes except where
   forced by C library wrappers)
2. Structured concurrency throughout (`async`/`await`, `TaskGroup`), no GCD
3. Modern, maintained dependencies from reputable orgs (`apple`, `swiftlang`,
   `vapor`, `hummingbird-project`)
4. Codable-based configuration replacing deprecated IBM Kitura `Configuration`
5. Proper code organization — larger files split by concern
6. Clean test suite that passes in a single `swift test` invocation on Linux
7. Single, simple CI workflow (direct Swift install, no nix)

**Every commit on this branch compiles and all tests pass on Linux (Swift 6.3.1).**

## Reconciliation scope

This branch supersedes three earlier exploration branches:

| Branch | Relationship |
|---|---|
| `origin/swift-61-2` | Initial Swift 6 migration (Swift 6.1.2). Base for the others. Accidentally committed a 5000-file `tmp/` directory. |
| `origin/swift-61` | `swift-61-2` + Phase 5 idioms + CI work + flake Swift 6. Most advanced of the three. |
| `origin/claude/modernize-swift-code-011CUL1a8VPtChzcZ9eLQeRT` | Functionally equivalent to `swift-61` minus one late test commit. |

`modernize-swift6` cherry-picks the substantive work from these branches, drops
the noise (`tmp/` pollution, duplicate CI attempts), and finishes the work that
was explicitly deferred in the old plan:

- Phase 4: GCD → `async`/`await` + `TaskGroup`
- Phase 5: type safety, file splitting, idiom sweep
- Proper `Sendable` on `Context` (replace `@unchecked`)
- GalleryTests isolation fix

The three old branches are left intact for history.

## Architecture

| Concern | Before | After |
|---|---|---|
| Swift toolchain | 5.8 | 6.3.1 |
| Package tools-version | 5.8 | 6.3 |
| Platform minimum | `.macOS(.v10_15)` | `.macOS(.v13)` |
| `Context` | `struct` with mutable fields + module-level GCD globals | truly `Sendable` struct; mutable pieces behind actors |
| `State` | `class` with GCD-queue-protected mutation | `actor State` with async mutators |
| Rate-limiting | `DispatchSemaphore` | `AsyncSemaphore` actor |
| Read pipeline | recursive synchronous fn with `DispatchQueue.async` fire-and-forget | `async throws` recursive fn using `withThrowingTaskGroup` |
| Write pipeline | `DispatchQueue.async` + `DispatchGroup.wait()` | `async throws` + `TaskGroup` |
| Photo collection | `var photos = [Photo]()` + `stateQueue.sync` appends | `TaskGroup` values aggregated in caller |
| `Gallery.init` | synchronous, spawns GCD work | `static func load(ctx:) async throws -> Gallery` |
| CLI | `ParsableCommand` + `run() throws` | `AsyncParsableCommand` + `run() async throws` |
| Config | Kitura `Configuration` + `swift-tools-support-core` | `Codable` `MuninConfiguration` + thin `ConfigurationManager` |
| Progress UI | `TSCBasic.stdoutStream` + TSC progress animations | `vapor/console-kit` `ActivityIndicator` |
| Paths | `String` + free `joinPath` helpers | `apple/swift-system` `FilePath` inside `Paths` namespace; public API stays `String`-based |
| File layout | `Photo.swift`, `Album.swift`, `Gallery.swift` as monoliths | split by concern |

## Dependencies

### Removed

- `Kitura/Configuration` 3.1.0 (deprecated) → replaced by in-tree Codable config
- `apple/swift-tools-support-core` 0.6.1 (deprecated) → replaced by
  `vapor/console-kit` + Foundation

### Bumped

- `apple/swift-log` 1.6.1 → 1.12.0
- `apple/swift-argument-parser` 1.4.0 → 1.7.1

### Added

- `apple/swift-system` 1.6.4 — `FilePath` for internal path helpers
- `vapor/console-kit` 4.16.0 — progress/terminal UI

### Unchanged

- `t089/swift-vips` (tracks `main`, SHA-pinned for reproducibility)
- `kradalby/SwiftExif` (currently SHA-pinned to master; see FUTURES.md — needs
  new upstream release tag incorporating Swift 6.3 fix)
- `onevcat/Rainbow` 4.0.1 — small color-output helper, kept

## Commit sequence

Each commit compiles and passes `swift test` on Linux.

| # | Commit | Summary |
|---|---|---|
| 1 | docs: add modernization plan | This document |
| 2 | package: Swift 6.3 tools + drop deprecated deps + bump | Package.swift + .swift-version |
| 3 | kit: Codable configuration system | New `Configuration.swift`; migrate `GalleryConfiguration`; ConfigurationTests |
| 4 | kit: replace TSC progress with vapor/console-kit | Remove TSC imports; use `ActivityIndicator` |
| 5 | kit: Sendable on value types | Annotate `Album`, `Photo`, `GPS`, `Keyword`, etc. |
| 6 | kit: State becomes an actor | `class State` → `actor State`; async mutators |
| 7 | kit: Context truly Sendable | Remove `@unchecked`; mutable pieces behind actors |
| 8 | kit: AsyncSemaphore | New actor-based semaphore + unit tests |
| 9 | kit: Gallery.load async | `static func load(ctx:) async throws -> Gallery` |
| 10 | kit: readStateFromInputDirectory via TaskGroup | Remove GCD read pipeline |
| 11 | kit: Album.write via TaskGroup | Remove GCD write pipeline |
| 12 | kit: drop Dispatch globals + ThreadSafeArray | Clean up now-unused globals |
| 13 | cli: AsyncParsableCommand | `main.swift` async; `await Gallery.load(...)` |
| 14 | kit: VIPS init lifecycle | Single init point; documented teardown |
| 15 | kit: Phase 5 modern idioms | Methods → computed properties; doc comments |
| 16 | kit: domain enums | `NO_HUGIN`, resolution constants, file extensions as types |
| 17 | kit: proper error types | `MuninError` enum; typed throws at boundaries |
| 18 | kit: split Photo.swift | `Photo+Read/+Write/+EXIF/+GPS.swift` |
| 19 | kit: split Album.swift | `Album+Read/+Write/+Clean/+Query.swift` |
| 20 | kit: Paths namespace using swift-system | Internal `FilePath` adoption (Scope A) |
| 21 | kit: fix Photo equality | Exclude `next`/`previous` from `Equatable` |
| 22 | test: fix GalleryTests isolation | Unique temp dirs; guarded LoggingSystem.bootstrap |
| 23 | flake: drop Swift, keep C deps only | Flake provides only libvips/libexif/libgd/libiptcdata; `nix build` removed |
| 24 | build: Makefile + README install instructions | Swiftly + tarball docs |
| 25 | ci: single Swift 6.3.1 workflow | Direct Swift install; replace existing workflows |
| 26 | example: regenerate output fixtures | Isolated regen commit |
| 27 | docs: remove plan, add FUTURES.md | Clean up; preserve research |

## Per-commit Linux verification

Before each commit:

1. `swift build 2>&1` — no errors, warnings reviewed
2. `swift test 2>&1` — all tests pass in a single invocation
3. Starting from commit 14: smoke test with `example/content` produces valid JSON

## Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| SwiftExif 0.0.7 incompatible with Swift 6.3 | Hit — fix exists upstream on master (`eb7c5c4`) | SHA-pin to master; request new tag in FUTURES.md |
| `swift-vips` `main` has breaking changes | Medium | SHA-pin for reproducibility |
| `console-kit` API fits Munin's progress needs poorly | Medium | Fallback to minimal in-tree `ProgressAnimation` |
| Strict Sendable forces wider `@unchecked` than expected | Medium | `@unchecked` only on VIPS wrapper with docs |
| GalleryTests isolation fix non-trivial | Medium | If root-cause exceeds budget, mark with `XCTSkip` + track in FUTURES.md |
| Regenerated `example/` drifts unexpectedly | Low | Isolated commit; reviewer can reject |

## Success criteria

- [ ] `swift build` clean on Linux with Swift 6.3.1
- [ ] `swift test` passes in a single invocation on Linux
- [ ] No `@unchecked Sendable` on domain types (only permitted on C-library wrappers with justification)
- [ ] No module-level `DispatchQueue` / `DispatchGroup` / `DispatchSemaphore`
- [ ] CI green on PR
- [ ] Generated JSON output format byte-identical to pre-change (except intentional regen)
- [ ] All deferred work captured in `FUTURES.md`

---

**Target toolchain:** Swift 6.3.1
**Platform target:** Ubuntu 24.04 (CI), macOS 13+ (secondary)
**Branch:** `modernize-swift6`
