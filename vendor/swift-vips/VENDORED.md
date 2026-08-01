# Vendored: swift-vips

This directory is a **vendored snapshot** of a third-party package, not Munin
code. It is checked in so it can be untangled later — everything below is
written so a future reader can reconstruct the upstream diff and push it back.

| | |
|---|---|
| True upstream | <https://github.com/t089/swift-vips> at `d01b393ef30b3a2ae6ed97a02f61edab3d44b4af` |
| Vendored from | <https://github.com/kradalby/swift-vips> at `bfebd9a0b758c813247f28212b2ec7d7a0f88bf0` |
| Referenced from | `Package.swift`, as `.package(path: "vendor/swift-vips")` |
| License | MIT — see `LICENSE`, unchanged |

There are therefore **two** deltas stacked here, and they untangle in opposite
directions:

* **The fork delta** — `d01b393..bfebd9a`, exactly one commit — is a genuine
  upstream fix and is **the piece to PR to t089**.
* **The Munin-local delta** — the four items under "Exactly what differs from
  upstream `bfebd9a`" below — exists only because Munin cross-compiles to musl
  and **must not go upstream**.

## The fork delta: glib ≥ 2.86 (`d01b393..bfebd9a`)

glib 2.86 tags `GLogLevelFlags` and `GConnectFlags` with `flag_enum`. Swift's
clang importer then stops importing `G_LOG_LEVEL_*` and `G_CONNECT_*` as
global constants, and upstream `swift-vips` no longer compiles against that
glib. The musl closure here builds glib 2.86.5 from source, so this is not
optional for Munin.

The single fork commit (`bfebd9a`, "Read glib flag enums through CvipsShim")
reads those constants through the `CvipsShim` C module instead of relying on
the importer. That works on both sides of the change — no version floor — so
it still builds against Ubuntu 24.04's glib 2.80.

This is the one change that belongs upstream. Until it lands there, Munin
cannot use `t089/swift-vips` directly.

## Why it is vendored at all

`swift-vips` generates its Swift wrappers with a SwiftPM **build-tool plugin**
(`Plugins/VIPSGeneratorPlugin`), which builds and runs a `vips-generator`
executable at build-plan time. That executable links `Cvips`, so it needs a
libvips for the **host**.

SwiftPM has a single, global pkg-config search path shared by the host tool and
the target being compiled. During a cross build (`swift build --swift-sdk
<arch>-swift-linux-musl`) that path has to point at the **musl** libvips, so the
host `vips-generator` fails to link:

```
[13/14] Linking vips-generator-tool
  undefined reference to 'SharpYuvInit'
  undefined reference to 'ffi_prep_cif'
  undefined reference to 'pcre2_compile_8'
```

There is no `PKG_CONFIG_PATH` arrangement that satisfies both at once. The same
plugin is also why Munin's Linux CI under `nix develop` failed with
`generatorFailed(status: 127)`.

So: the plugin's output is pre-generated and checked in, and the plugin is
unhooked. Nothing regenerates at build time, and `.build/plugins/outputs` is
never created.

Two properties make a pre-generated snapshot safe against a *different* libvips
than the one it was generated from, both verified:

* The generated code dispatches every operation by **nickname string** — 295
  `Self.call("...")` sites, and only two direct C calls
  (`vips_array_double_get`, `vips_area_unref`). A libvips missing an operation
  fails at **runtime**, not at link time.
* Every C enum the wrappers reference (`VipsForeignHeifCompression`,
  `VipsForeignTiffCompression`, `VipsForeignWebpPreset`, …) is declared
  unconditionally in `vips/foreign.h`, even in a build with those loaders
  disabled.

Confirmed end to end: wrappers generated against Ubuntu's libvips 8.15.1 build
and link against a from-source musl libvips 8.16.1, and the resulting binary
renders the full `example/` gallery correctly.

## Exactly what differs from upstream `bfebd9a`

1. **`Package.swift`** — removed `plugins: [.plugin(name: "VIPSGeneratorPlugin")]`
   from the `VIPS` target. Marked in place with a `// VENDORED:` comment.
2. **`Package.swift`** — removed the `VIPSTests` test target, because (3)
   removes the fixtures it needs. Marked in place with a `// VENDORED:` comment.
3. **`Sources/VIPS/Generated/`** — added. 19 `*.generated.swift` files, 10,504
   lines, produced by `vips-generator` (see below). Upstream does not check
   these in; they normally live in the plugin's work directory.
4. **Deleted**, none of it reachable from the `VIPS` product:
   * `Tests/` (48 MB of image fixtures) and `Examples/`.
   * `.github/` — its workflow would otherwise be picked up by tooling that
     scans this repository for workflows.
   * the upstream `.git`.
   * `CLAUDE.md` — not inert. It is an instruction file agents load, and it
     documents the build-tool plugin as running automatically during
     `swift build`, which is exactly the behaviour (3) removes.
   * `.vscode/` — debug configuration for the `vips-tool` executable, which
     nothing in Munin builds.
   * `.spi.yml` — Swift Package Index build metadata, meaningful only for the
     upstream repository.

Everything else — `Sources/{Cvips,CvipsShim,VIPS,VIPSIntrospection,VIPSGenerator,vips-tool}`,
`Plugins/`, `docs/`, `README.md`, `LICENSE`, `.gitignore`, `.swift-format` —
is byte-for-byte upstream. `Plugins/`, `VIPSGenerator`, `vips-tool` and
`docs/` are kept deliberately: they are what makes regeneration (below)
possible.

Note that `README.md` is upstream's and still describes the plugin as running
automatically during `swift build`. That is left alone to keep the untangle
diff minimal; **this file** is the authority on how the vendored copy actually
behaves.

The `VIPSGeneratorPlugin`, `vips-generator` and `VIPSIntrospection` targets are
kept. They are simply unreachable from the `VIPS` product, so a Munin build
never builds them — but they keep manual regeneration possible.

## Regenerating the wrappers

The wrappers are name-dispatched, so regenerate against whatever libvips is
current; there is no version to match. On a glibc machine with `libvips-dev`
installed:

```sh
cd vendor/swift-vips
swift run vips-generator --output-dir Sources/VIPS/Generated
```

Do this on **glibc**, never inside a cross build — `vips-generator` links
libvips for the host, which is the whole reason the plugin was removed.

## Untangling this

Two independent steps, in this order.

**1. Get the fork delta into `t089/swift-vips`.** It is one commit and it is
not Munin-specific:

```sh
git clone https://github.com/kradalby/swift-vips /tmp/swift-vips
cd /tmp/swift-vips
git log -p d01b393ef30b3a2ae6ed97a02f61edab3d44b4af..bfebd9a0b758c813247f28212b2ec7d7a0f88bf0
# -> one commit, "Read glib flag enums through CvipsShim". PR that to t089.
```

Once it lands upstream, the fork can be retired and this file's "vendored
from" row becomes `t089/swift-vips` at whatever revision carries it.

**2. Drop the vendoring itself.** This only becomes possible when the
build-tool plugin can coexist with a musl cross build (SwiftPM would need
separate pkg-config paths for host tools and target). Until then Munin needs
the checked-in wrappers regardless of who owns the fork. Divergences (1), (2),
(3) and (4) above are all Munin-local and must **not** be carried upstream.

When both are true, Munin's `Package.swift` goes back to
`.package(url: ..., revision: ...)` and this directory is deleted.
