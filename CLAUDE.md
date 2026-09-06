# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

AeroSpace is an i3-like tiling window manager for macOS, written in Swift 6.3 (SPM-driven). It does not require disabling SIP and uses only one private accessibility API (`_AXUIElementGetWindow`). Avoid introducing further "dark magic" (private APIs, code injection). Avoid GUI surfaces beyond the menu bar icon — config is plain text TOML.

## Build / test / run

All entry-point scripts live at the repo root. They `cd` to the repo root and `source ./script/setup.sh`, so always invoke via `./script/...` from the project root rather than copying the underlying `swift` invocation.

- `./build-debug.sh` — debug build via SPM into `.debug/`. Calls `./generate.sh --ignore-xcodeproj --ignore-cmd-help --ignore-shell-parser` first; pass any extra `swift build` flags through.
- `./run-debug.sh` — build + run `.debug/AeroSpaceApp`.
- `./run-cli.sh <args>` — build + run `.debug/aerospace` with forwarded args (CLI client).
- `./swift-test.sh` — `swift test` with noisy lines stripped. Single test: `swift test --filter <SuiteName>[/<testName>]` (e.g. `swift test --filter LayoutTests/testTabbing`).
- `./test.sh` — full CI gate: clean-tree check → debug build with `-warnings-as-errors` → swift tests → CLI smoke (`-h`, `-v`) → `lint.sh --check-uncommitted-files` → `generate.sh` → second clean-tree check. Run before declaring work done.
- `./format.sh` — runs swiftformat then swiftlint `--fix` (auto-installs both into `.deps/`).
- `./lint.sh` — periphery dead-code scan with `--strict` (skipped on macOS 14 due to a periphery dylib bug).
- `./generate.sh` — regenerates `Sources/Common/versionGenerated.swift`, `Sources/Common/gitHashGenerated.swift`, `Sources/Cli/subcommandDescriptionsGenerated.swift`, the shell parser (under `ShellParserGenerated/`), and `AeroSpace.xcodeproj` (via xcodegen + `project.yml`). Use `--ignore-xcodeproj`/`--ignore-cmd-help`/`--ignore-shell-parser` to skip parts. **Files ending in `Generated.swift` are output of this script — never hand-edit them; change the source (`docs/aerospace-*.adoc`, `grammar/*`) and rerun.**
- `./build-release.sh` — Xcode-driven universal release build into `.release/` (Xcode 26+, requires the `aerospace-codesign-certificate` self-signed identity). Not needed for normal dev.
- `./build-docs.sh` / `./build-shell-completion.sh` — site/manpages and shell completion artifacts.
- `make <script>.sh` works (the `makefile` just shells out) so `:make` in vim is wired up.

## Codesigning for local debug

Debug builds run unsigned from terminal. To run as `.app` with stable accessibility permission, create a self-signed cert in Keychain Access named `aerospace-codesign-certificate` (see `dev-docs/development.md`). In Xcode: File → Open `Package.swift` (not the xcodeproj), then Edit Scheme → Options → Console → Terminal so accessibility permission is granted to Terminal once instead of on every rebuild.

## Architecture

Two binaries, three SPM targets, one shared library:

- `Sources/Cli/` (`aerospace` executable) — thin client. Parses args, sends them over a UNIX socket to the running app, prints stdout/stderr, exits with the server's exit code. Depends on `Common` only.
- `Sources/AeroSpaceApp/` — App Bundle entry point (the actual `AeroSpace.app`). Depends on `AppBundle`. Tiny — almost everything is in the library.
- `Sources/AppBundle/` — server library (the real window manager). Depends on `Common`, `PrivateApi`, and external packages (HotKey, ISSoundAdditions, swift-collections, TOMLDecoder, ShellParserGenerated).
- `Sources/Common/` — shared between client and server: command-line arg models (`cmdArgs/`), util, generated version/hash.
- `Sources/PrivateApi/` — C shim exposing `_AXUIElementGetWindow`.

The reason for this split: SPM cannot build macOS `.app` bundles, only CLIs/libraries. So `AppBundle` is a library that Xcode wraps into the app via the generated `AeroSpace.xcodeproj` (skeleton in `project.yml`). Most logic lives in `AppBundle` so SourceKit-LSP works without Xcode.

### Client/server protocol

Each CLI invocation:
1. Client parses args (errors / `--help` short-circuit here).
2. Args are sent to the server over a predefined UNIX socket (see `Sources/AppBundle/server.swift`).
3. Server re-parses and executes against the live tree.
4. Server returns stdout/stderr/exit code; client prints and exits.

This means **command logic lives in the server**, but **arg models are shared in `Common/cmdArgs/`** so both sides agree on the wire format.

### Server subsystems (`Sources/AppBundle/`)

- `tree/` — the core data model. `TreeNode` is the abstract base; concrete cases are workspaces, tiling containers (split H/V, accordion, **tabs** — see `tabHeaders.swift`), windows, and `MacosUnconventionalWindowsContainer` for floating/fullscreen escape hatches. **Note:** the tree is currently mutable + double-linked. There is an in-flight rewrite to an immutable single-linked persistent tree (issue #1215) — be conservative when refactoring tree internals.
- `layout/` — applies the tree to actual macOS window frames. `refresh.swift` is the main reconcile loop; `layoutRecursive.swift` walks the tree and computes frames; `tabHeaders.swift` draws tab strip overlays via `TabHeadersView`.
- `command/` — every user-facing command (`focus`, `move`, `workspace`, `mode`, `layout`, …) lives in `command/impl/`. `cmdManifest.swift` is the registry. `frozen/` contains commands that operate on a snapshot (split brain between mutable tree and command execution).
- `config/` — TOML config parser (TOMLDecoder) and validation. Config errors must be surfaced with line numbers.
- `model/` — runtime singletons: focus state, monitor model, mode state.
- `mouse/` — drag/resize/hover handling driven by mouse events.
- `shell/` — shell-combinator parser glue (the upcoming `&&`/`||`/`;`/`eval` work, issue #278). The actual lexer/parser is generated from `grammar/Shell{Lexer,Parser}.g4` into the separate `ShellParserGenerated` package.
- `ui/` — the small AppKit surface: status menu icon, `TabHeadersView`. No config GUI by design.
- `GlobalObserver.swift` / `runLoop.swift` / `subscriptions.swift` — AX-event observation and the main run-loop tick.
- `focus.swift` / `focusCache.swift` / `getNativeFocusedWindow.swift` / `windowLevelCache.swift` — focus tracking; aggressively cached because AX calls are blocking and slow.

### Adding a new command

When adding a command, the contributor checklist (per `dev-docs/architecture.md`) is:
- Command impl in `Sources/AppBundle/command/impl/`, registered in `cmdManifest.swift`.
- Arg model in `Sources/Common/cmdArgs/` (shared with CLI).
- Docs in `docs/aerospace-<cmd>.adoc` and `docs/commands.adoc` (asciidoc, fed into manpages and the site).
- Decide if `--window-id` and/or `--workspace` flags apply.
- Update shell completion grammar in `grammar/commands-bnf-grammar.txt`.
- Run `./generate.sh` to regenerate `subcommandDescriptionsGenerated.swift` and `cmdHelpGenerated.swift`.

## Conventions

- Swift 6.3, strict memory safety, `NonisolatedNonsendingByDefault` upcoming feature on. Treat warnings as errors when in doubt — `./test.sh` does.
- Formatting: swiftformat config in `.swiftformat` (tabs of 4 spaces, no semicolons, trailing closures, etc., explicit allowlist of rules). swiftlint config in `.swiftlint.yml`. Always `./format.sh` before committing.
- **Generated files** (`*Generated.swift`, `ShellParserGenerated/`, `AeroSpace.xcodeproj/`) must be regenerated, not hand-edited. CI's `script/check-uncommitted-files.sh` will fail otherwise.
- **Commit hygiene** (from `CONTRIBUTING.md`): each commit is one atomic change; do not mix refactors with feature changes; commit messages describe what / why / how.
- **Don't refactor along the way.** When fixing a bug or adding a feature, stick to the existing code structure even if you'd prefer something else — the maintainer prefers PRs that don't bundle drive-by cleanup.
- **No GUI for config**, no animations / borders / transparency / "ricing" features — those proposals will be rejected on principle (see `README.md` "Project values"). Performance and correctness only.
- This project does **not** accept GitHub Issues directly — bugs and feature ideas are filed as Discussions first. Don't open Issues from automated workflows.

## Useful tools while debugging

- `Accessibility Inspector.app` (built into macOS) to inspect AX properties of windows.
- `aerospace debug-windows` for window-handling bug reports.
- `script/clean-project.sh` when build state goes sideways.
- `script/reset-accessibility-permission-for-debug.sh` if AX permission gets stuck.
- DeskPad / BetterDisplay 2 to emulate multi-monitor setups locally.
