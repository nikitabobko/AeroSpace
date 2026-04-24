# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

AeroSpace is an i3-like tiling window manager for macOS. This repo is the
**AdrianLSY fork** of [nikitabobko/AeroSpace](https://github.com/nikitabobko/AeroSpace)
that adds hover-to-raise (AutoRaise). Fork-specific code lives in
`Sources/AutoRaiseCore/` (ObjC++, GPL-2.0-or-later) and
`Sources/AppBundle/autoraise/` (Swift). Everything else mirrors upstream
and is MIT; the combined binary ships under GPL-2.0-or-later because of
the AutoRaise linkage.

See [FORK.md](FORK.md), [CONTRIBUTING.md](CONTRIBUTING.md), and
[dev-docs/fork-maintenance.md](dev-docs/fork-maintenance.md) for fork
context; [dev-docs/development.md](dev-docs/development.md) for env
setup and tooling; [dev-docs/architecture.md](dev-docs/architecture.md)
for the upstream architecture primer.

## Commands

All scripts live at repo root; invoke them with `./name.sh`. They all
`cd` to repo root and `source script/setup.sh`, which pins toolchains
via `swiftly` when available.

**Primary dev loop**
- `./build-debug.sh` — SPM debug build into `.debug/`. Fast inner loop.
  Skips xcodeproj/cmd-help/shell-parser regeneration by default.
- `./swift-test.sh` — `swift test` with pruned output. Add
  `--filter <TestCaseName>` or `--filter <TestCaseName>/<testMethod>`
  to target a single test (pass-through to `swift test`).
- `./test.sh` — CI-equivalent: debug build with warnings-as-errors,
  full test suite, CLI smoke tests, `./lint.sh`, `./generate.sh`, and a
  check that no generated files are uncommitted. Run this before
  opening a PR (required by `.github/pull_request_template.md`).
- `./format.sh` — swiftformat + swiftlint `--fix`.
- `./lint.sh [--check-uncommitted-files]` — format + periphery dead-code
  scan. Note: periphery is skipped on macOS 14/15/26 (see comments
  inside `lint.sh` for details — it can't run anywhere right now).
- `./run-debug.sh [args]` — rebuild + launch `.debug/AeroSpaceApp`.
- `./run-cli.sh [args]` — rebuild + invoke `.debug/aerospace` with
  forwarded args against the already-running server.

**Release / packaging**
- `./build-release.sh` — Xcode-driven universal release build into
  `.release/`. Debug builds never use Xcode; release builds must.
- `./install-from-sources.sh` — builds release + installs as
  `aerospace-adrianlsy` Homebrew cask (fork-specific uninstall list;
  do not rebrand on rebase).
- `./build-docs.sh` / `./build-shell-completion.sh` — generate the
  docs site (`.site/`), man pages (`.man/`), and shell completions
  (`.shell-completion/`).

**Code generation**
- `./generate.sh` regenerates `AeroSpace.xcodeproj` and several Swift
  source files. Regenerated outputs (named `*Generated.swift` in
  `Sources/Common/` and `Sources/Cli/`) **must be committed** —
  `./test.sh` fails if they drift. Re-run after:
  - editing `project.yml` (xcodeproj)
  - adding/removing/renaming `docs/aerospace-*.adoc` (subcommand
    descriptions in the CLI `--help`)
  - editing shell grammar under `grammar/` (regenerate with
    `./script/generate-shell-parser.sh`)
- `swift-version` is pinned in `.swift-version`; `swiftly` in
  `script/setup.sh` enforces it.

## Architecture

### Client/server split

`aerospace` CLI binary (`Sources/Cli`) is the client. `AeroSpace.app`
(`Sources/AeroSpaceApp` entry point, `Sources/AppBundle` library) is
the server. They communicate over a Unix socket (`server.swift`,
client code in `Sources/Cli/_main.swift`). Args are parsed on the
client (for `--help` / early-exit shortcuts), sent over the socket,
then **re-parsed on the server** via the same code in
`Sources/Common/cmdArgs/`. That shared-parser constraint is why arg
parsing and command arg structs live in `Common/` — both client and
server link them.

### SPM vs Xcode

Library code and the CLI build **purely via SPM** (`Package.swift`).
SPM cannot produce a macOS App Bundle, so the App Bundle is built via
Xcode against the generated `AeroSpace.xcodeproj` (generated from
`project.yml` via `xcodegen`). Push as much code as possible into the
SPM library (`Sources/AppBundle`) — the Xcode target is just a thin
entry point. Open `Package.swift` in Xcode, not `.xcodeproj`, unless
you're debugging the release build.

### Command pipeline

A command is defined in three places:

1. **`Sources/Common/cmdArgs/impl/<Name>CmdArgs.swift`** — argument
   struct. Also registered in the `CmdKind` enum +
   `initSubcommands()` switch in
   `Sources/Common/cmdArgs/cmdArgsManifest.swift`.
2. **`Sources/AppBundle/command/impl/<Name>Command.swift`** —
   server-side `Command` conformance (`run(env, io) async throws`).
   Also wired into the `toCommand()` switch in
   `Sources/AppBundle/command/cmdManifest.swift`.
3. **`docs/aerospace-<name>.adoc`** — docs + man page + the CLI
   `--help` subcommand summary (pulled by `generate.sh` from
   `:manpurpose:`).

Adding or renaming a command without touching all three breaks the
build or the `./test.sh` "no uncommitted generated files" check.

### Refresh sessions (focus + layout reconciliation)

The central reconciliation primitive lives in
`Sources/AppBundle/layout/refresh.swift`:

- `runHeavyCompleteRefreshSession` — full `getNativeFocusedWindow` →
  model refresh (`MacApp.refreshAllAndGetAliveWindowIds` + GC) →
  layout pass. Kicked off by NSWorkspace notifications and AX
  observers via `scheduleCancellableCompleteRefreshSession`.
- `runLightSession` — wraps command execution. Cancels any in-flight
  heavy session, runs the command body, relayout, syncs focus, then
  reschedules a heavy session. Commands received via the socket
  server always run inside a `runLightSession`.

`TrayMenuModel.shared.isEnabled` (aka "the master switch", toggled
by `enable on/off`) gates both. When disabled, workspaces are
stashed into off-screen corners (see `hideInCorner`/`unhideFromCorner`
in `refresh.swift`).

### Tree model

`Sources/AppBundle/tree/`:

- `TreeNode` — base class. Every node records `lastAppliedLayoutPhysicalRect`
  (real gaps) and `lastAppliedLayoutVirtualRect` (zero gaps); many
  commands read these without re-querying AX.
- `Workspace`, `TilingContainer`, `Window` / `MacWindow` — concrete
  nodes. `Window.get(byId:)` has a unit-test branch that walks
  workspaces instead of `MacWindow.allWindowsMap`.
- `MacosUnconventionalWindowsContainer` holds fullscreen/minimized/
  hidden-app windows off the main tree; `normalizeLayoutReason.swift`
  shuttles windows in and out based on macOS state.

### Focus

`focus.swift` owns the global `LiveFocus` (derived) and `FrozenFocus`
(stored, safe to hold). Command implementations should generally
respect `--window-id` / `--workspace` / `AEROSPACE_WINDOW_ID` /
`AEROSPACE_WORKSPACE` env first and fall back to the global only when
none applies. Focus changes go through `setFocus(to:)` (updates the
tree model) paired with `Window.nativeFocus()` (AX-side raise + app
activate) — see `GlobalObserver`, `RaiseRouter`, and the end of
`runLightSession` for how the pair is used consistently.

### AutoRaise integration (fork-specific)

The AutoRaise port has two layers:

- **`Sources/AutoRaiseCore/`** (ObjC++, GPL-2.0-or-later). `AutoRaise.mm`
  is the ported upstream; `AutoRaiseBridge.{h,mm}` is the C API the
  Swift side calls. The ObjC++ globals in `AutoRaise.mm` are the
  source of truth at runtime — the bridge writes config fields and
  resets runtime-state fields on each start. The CGEventTap and
  retry timers are pinned to the **main run loop** so raise routing
  can stay synchronous.
- **`Sources/AppBundle/autoraise/`** (Swift). `AutoRaiseController` is
  a `@MainActor` singleton that reconciles four state sources:
  1. `[auto-raise]` TOML section (startup + file-watcher reloads).
  2. `enable-auto-raise` / `disable-auto-raise` CLI commands
     (`runtimeDisabled` is **sticky across config reloads** — see
     comments in `AutoRaiseController.swift`).
  3. Master `enable on/off` via `pauseForMaster`/`resumeFromMaster`
     (snapshots running state; *not* sticky).
  4. NSWorkspace observer fan-out from `GlobalObserver` (active-space
     / app-activated notifications).

  `RaiseRouter.route(windowId:)` is the C→Swift callback:
  resolve `CGWindowID` → `Window`, drop if target is on a non-focused
  workspace, then call `focusWindow()` + `nativeFocus()`. Integration
  points in the upstream codebase:
  - `initAppBundle.swift` — boot-time start.
  - `GlobalObserver.swift` — fan-out to `onActiveSpaceDidChange` /
    `onAppDidActivate`.
  - `EnableCommand.swift` — pause/resume on master toggle.
  - `refresh.swift` — `onLayoutDidChange` hook at end of
    `runLightSession`, used for the cursor-over-window hit test after
    AeroSpace-driven layout changes.

  The `AutoRaiseBridgeProtocol` seam exists so
  `AutoRaiseControllerTest` can drive the state machine with
  `FakeAutoRaiseBridge` without installing a real CGEventTap.

### Private API

`Sources/PrivateApi/` exposes exactly one private symbol:
`_AXUIElementGetWindow`. This is the only private API in the project
and the codebase's guiding principle is to keep it that way.

### Generated code

These files are produced by `generate.sh` and checked in. Don't edit
them by hand:

- `Sources/Common/versionGenerated.swift`
- `Sources/Common/gitHashGenerated.swift`
- `Sources/Common/cmdHelpGenerated.swift`
- `Sources/Cli/subcommandDescriptionsGenerated.swift`
- `AeroSpace.xcodeproj/` (regenerated from `project.yml`)
- `ShellParserGenerated/Sources/**` (regenerated from `grammar/*.g4`)

## Conventions that will catch you out

- **Swift strict concurrency.** `Package.swift` enables
  `NonisolatedNonsendingByDefault` and `.strictMemorySafety()`. Most
  mutable globals are `@MainActor`. Cross-actor calls need explicit
  annotations; `unsafe` is required for the few `nonisolated(unsafe)`
  globals.
- **Config reloads are hot.** `ConfigFileWatcher` + `reload-config`
  both call through the same parsing path in `parseConfig.swift`.
  Preserve runtime toggle state when adding new config fields
  (mirror the `AutoRaise` pattern: sticky flag on the controller,
  not in config).
- **`runLightSession` is single-flight.** It cancels any in-flight
  heavy refresh. If you add a code path that mutates the tree, route
  it through `runLightSession` or `refreshModel()` so the
  `on-focus-changed` / broadcast machinery stays consistent.
- **Rebase, don't merge.** The fork's `main` is kept rebased on
  `nikitabobko/main`. No merge commits. Expected conflict set on
  rebase is listed in
  [dev-docs/fork-maintenance.md](dev-docs/fork-maintenance.md#expected-conflict-set)
  — consult it before resolving conflicts yourself.
- **Licensing split matters at file granularity.** Contributions to
  `Sources/AutoRaiseCore/**` are GPL-2.0-or-later; everywhere else is
  MIT. The PR template calls this out.
