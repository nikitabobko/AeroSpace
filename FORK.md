# AdrianLSY/AeroSpace — Fork of [nikitabobko/AeroSpace](https://github.com/nikitabobko/AeroSpace)

This is a public fork of AeroSpace, the i3-like tiling window manager for
macOS. It tracks upstream closely and adds fork-specific functionality on
top.

## What this fork adds

**Hover-to-raise (AutoRaise).** Focus follows your mouse cursor into any
window on the currently-focused workspace. Port of
[sbmpost/AutoRaise](https://github.com/sbmpost/AutoRaise), integrated
through AeroSpace's existing focus machinery (not bolted on — it respects
the current workspace, pauses when the master switch is off, and routes
every raise through `window.focusWindow()` so the tree model, monitor
state, and `on-focus-changed` callbacks stay consistent).

- Configure via the `[auto-raise]` section in your `aerospace.toml`.
  See the [auto-raise guide section](https://adrianlsy.github.io/AeroSpace/guide#auto-raise).
- Toggle at runtime with `aerospace enable-auto-raise` /
  `aerospace disable-auto-raise`.
- Pauses automatically when AeroSpace's master switch is off
  (`aerospace enable off`); resumes at prior running state on `enable on`.
  A sticky `disable-auto-raise` survives the cycle.

Everything else in this fork matches upstream. For unchanged behavior refer
to upstream's [user guide](https://adrianlsy.github.io/AeroSpace/guide) —
the fork's docs site at
[adrianlsy.github.io/AeroSpace](https://adrianlsy.github.io/AeroSpace)
mirrors the same content with a fork header.

## Installation

```bash
brew tap AdrianLSY/tap
brew install --cask aerospace-adrianlsy
```

Or in one command:

```bash
brew install --cask AdrianLSY/tap/aerospace-adrianlsy
```

The `aerospace-adrianlsy` cask `conflicts_with 'aerospace'`, so you can't
install both simultaneously — pick one.

Other installation options (manual zip download, build from source) match
upstream; see upstream's
[installation guide](https://adrianlsy.github.io/AeroSpace/guide#installation)
for details.

## Relationship to upstream

- **Rebase-based.** Fork's `main` stays rebased on `nikitabobko/main`.
  Upstream commits arrive as-is; fork-specific commits sit on top. No merge
  commits in the fork's `main`.
- **Version scheme.** `v<upstream-version>-Beta.adrianlsy.<n>` — mirrors
  upstream's `-Beta` pre-release marker (the combined binary is genuinely
  a beta of a beta). SemVer-compliant dot-separated pre-release chain:
  - `v0.20.0-Beta.adrianlsy.1` — first fork release after upstream's
    `v0.20.0-Beta`.
  - `v0.20.0-Beta.adrianlsy.2` — fork bugfix with no upstream change.
  - When upstream releases `v0.21.0-Beta` and the fork rebases, the next
    fork tag resets to `v0.21.0-Beta.adrianlsy.1`.
- **Where to file bugs:**
    Bug reports can be filed at
    **[this repo's issues](https://github.com/AdrianLSY/AeroSpace/issues)** —
    both fork-specific and upstream behavior bugs are accepted.
    For upstream AeroSpace bugs you can also file at
    **[upstream discussions](https://github.com/nikitabobko/AeroSpace/discussions)**
    if you prefer. Either place works.

## License

The fork's combined binary is distributed under **GPL-2.0-or-later**, a
consequence of linking in the AutoRaise port. Individual source files
retain their original license headers:

- `Sources/AutoRaiseCore/**` — GPL-2.0-or-later (derived from
  [sbmpost/AutoRaise](https://github.com/sbmpost/AutoRaise)).
- Everything else in the fork — MIT, inherited from upstream AeroSpace.

Full texts: [LICENSE.txt](./LICENSE.txt) (MIT), [LICENSE-GPL](./LICENSE-GPL)
(GPL-2.0). Bundled dependency licenses: [legal/README.md](./legal/README.md).

## For maintainers

See [dev-docs/fork-maintenance.md](./dev-docs/fork-maintenance.md) for:

- Rebase protocol: files that diverge from upstream and how to resolve them.
- Release workflow: tag naming, CI pipeline, Homebrew tap update.
- Docs-site deployment.
- Upstream sync cadence.
