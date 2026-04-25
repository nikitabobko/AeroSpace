# Fork Maintenance

Operational notes for maintaining `AdrianLSY/AeroSpace` rebased on
`nikitabobko/main`.

## Rebase protocol

```bash
git fetch upstream
git rebase upstream/main
# resolve conflicts (see below)
./test.sh
git push --force-with-lease origin main
```

### Expected conflict set

These files diverge from upstream by design. Each rebase will re-surface
a conflict on them; keep the fork side and continue.

| File | Conflict type | Resolve by |
|------|---------------|------------|
| `README.md` | Prefix banner + Key-features reordering + Fork-install block | Keep fork header/banner; accept upstream edits to body; verify AutoRaise bullet is still at top of "Key features" |
| `CONTRIBUTING.md` | Fork section prepended above `---` divider | Keep fork preamble; accept upstream edits to the body below the divider |
| `docs/util/header.adoc` | Added "Fork homepage" line above upstream's "Project homepage" line | Keep both lines |
| `.github/pull_request_template.md` | Replaced wholesale | Keep fork version |
| `.github/ISSUE_TEMPLATE/config.yml` | Reconfigured contact_links | Keep fork version |
| `.github/ISSUE_TEMPLATE/fork-*.yml`, `upstream-redirect.md` | New files (no upstream equivalent) | N/A — no conflict |
| `.github/ISSUE_TEMPLATE/new-issue.yml` | Removed in fork | Delete again if upstream re-introduces |
| `.github/workflows/close-third-party-issues.yml` | Removed in fork | Delete again if upstream re-introduces |
| `script/build-brew-cask.sh` | Added `aerospace-adrianlsy` case + `--homepage` flag | Re-apply fork hunk |
| `install-from-sources.sh` | Added `aerospace-adrianlsy` to pre-install uninstall list | Re-apply fork hunk |
| `CLAUDE.md` | Fork-specific architecture notes | Keep fork version |
| `docs/guide.adoc` | Dwindle layout + `[dwindle]` config section, plus AutoRaise section | Keep both fork sections; accept upstream edits to other parts |
| `docs/aerospace-layout.adoc` | Synopsis + body extended for `dwindle\|h_dwindle\|v_dwindle` | Re-apply fork hunk to synopsis line and body |
| `docs/config-examples/default-config.toml` | Commented `[dwindle]` example block + `dwindle` listed in `default-root-container-layout` comment | Re-apply fork hunks |
| `Sources/AppBundle/tree/TilingContainer.swift` | `Layout.dwindle` enum case + `preserveSplit: Bool` field | Re-apply additions; verify other call-sites still cover all enum cases |
| `Sources/AppBundle/tree/MacWindow.swift` | `unbindAndGetBindingDataForNewTilingWindow` calls `DwindleInsertion.compute` before falling through to standard logic | Re-apply the dwindle branch at the top of the function |
| `Sources/AppBundle/tree/normalizeContainers.swift` | `unbindEmptyAndAutoFlatten` checks `!preserveSplit` before single-child collapse | Re-apply guard |
| `Sources/AppBundle/config/Config.swift` | `var dwindle: DwindleConfig = DwindleConfig()` | Re-apply field |
| `Sources/AppBundle/config/parseConfig.swift` | `"dwindle"` parser entry in `configParser` table | Re-apply line |
| `Sources/AppBundle/command/impl/LayoutCommand.swift` | New cases for `.dwindle`, `.h_dwindle`, `.v_dwindle` in `matchesDescription` and the dispatch switch | Re-apply additions |
| `Sources/AppBundle/model/Json.swift` | Added `case double(Double)` and `asDoubleOrNil` | Required by `[dwindle]` float-valued options. Re-apply if upstream rebases over this. |
| `Sources/Common/cmdArgs/impl/LayoutCmdArgs.swift` | `LayoutDescription` adds `dwindle`, `h_dwindle`, `v_dwindle` | Re-apply additions |

Files that stay upstream-shaped — do not rebrand on rebase:

- `dev-docs/architecture.md`, `dev-docs/development.md` — upstream-correct.
- `Sources/**/*.swift` — upstream architecture; fork-specific code is
  confined to `Sources/AutoRaiseCore/**`, `Sources/AppBundle/autoraise/**`,
  and `Sources/AppBundle/dwindle/**`. Each rarely conflicts with upstream
  except where a hook is wired into a conflict-prone file (see table).
- `legal/README.md`, `third-party-license/**` — dependency licenses.
- `.github/FUNDING.yml` — intentionally unchanged; sponsorship still
  credits upstream maintainer.

### Fork-specific divergences

Two deliberate divergences from upstream `nikitabobko/main`:

1. **AutoRaise** — see `Sources/AutoRaiseCore/**`,
   `Sources/AppBundle/autoraise/**`. GPL-2.0-or-later because the AutoRaise
   port is GPL.
2. **Dwindle layout** — see `Sources/AppBundle/dwindle/**`,
   `Sources/AppBundleTests/dwindle/**`. MIT (does not touch
   `Sources/AutoRaiseCore/`). Tracks Hyprland's `dwindle` plugin behaviour.
   Upstream's [#260](https://github.com/nikitabobko/AeroSpace/issues/260)
   tracks dynamic layouts but has no implementation as of 2026-04. If
   upstream lands a different design, accept the rework cost; isolated
   logic in `Sources/AppBundle/dwindle/` keeps the call-site disruption
   small.

## Release workflow

### Tag naming

```
v<upstream-version>-Beta.adrianlsy.<n>
```

- `<upstream-version>` is the upstream version the fork is currently
  rebased on (e.g. `0.20.0`, matching upstream's `v0.20.0-Beta` tag).
- `-Beta.` mirrors upstream's pre-release marker. It stays in the fork
  tag so the version string is honest ("beta of a beta") and SemVer sorts
  the fork tag below a hypothetical stable `v0.20.0`.
- `<n>` is the fork patch counter; resets to `1` per upstream version.
- Dot-separated chain (`-Beta.adrianlsy.N`) is idiomatic SemVer
  pre-release. Homebrew accepts it; tooling that treats dash-suffixes as
  pre-releases behaves correctly for a fork whose tags never interleave
  with upstream's in a single channel.
- If upstream ever drops the `-Beta` marker (e.g. cuts a 1.0 release),
  update the regex in
  [script/publish-release-adrianlsy.sh](../script/publish-release-adrianlsy.sh)
  and
  [.github/workflows/release-adrianlsy.yml](../.github/workflows/release-adrianlsy.yml)
  to match the new upstream shape.

### What fires on tag push

Pushing a matching tag to `AdrianLSY/AeroSpace` triggers two workflows:

1. **[.github/workflows/release-adrianlsy.yml](../.github/workflows/release-adrianlsy.yml)**
   — builds the release binary, creates the GH Release with the zip
   attached, regenerates the Homebrew cask, opens a PR against
   `AdrianLSY/homebrew-tap`.
2. **[.github/workflows/pages.yml](../.github/workflows/pages.yml)** —
   builds `.site/` via `./build-docs.sh`, deploys to GitHub Pages.

### Cutting a release

```bash
git checkout main
git pull
./test.sh                                   # sanity check
git tag -a v0.20.0-Beta.adrianlsy.1 -m "Release v0.20.0-Beta.adrianlsy.1"
git push origin v0.20.0-Beta.adrianlsy.1
```

Then:

- Watch the release workflow in Actions. If it fails, fix and re-tag as
  `-Beta.adrianlsy.<n+1>` — don't mutate existing tags.
- Review the auto-opened tap PR at
  `AdrianLSY/homebrew-tap`. For the first few releases, merge manually
  after visually verifying the generated `.rb` (`sha256`, `url`,
  `version` all make sense). Once the pipeline has been validated
  across 2-3 releases, auto-merge can be enabled.
- Verify the Pages deployment at
  https://adrianlsy.github.io/AeroSpace — the fork banner should appear
  in the site header.

### Manual release fallback

If Actions is unavailable or the workflow fails in a way that needs
local debugging, use
[script/publish-release-adrianlsy.sh](../script/publish-release-adrianlsy.sh):

```bash
./script/publish-release-adrianlsy.sh \
  --build-version 0.20.0-Beta.adrianlsy.1 \
  --tap-git-repo-path /path/to/AdrianLSY/homebrew-tap
```

The script runs `./test.sh`, builds the release, pushes the tag, opens
the GH release creation page, and copies the generated cask into the
local tap checkout. You commit + push the tap repo yourself.

## Tap repo (`AdrianLSY/homebrew-tap`)

Separate repo at https://github.com/AdrianLSY/homebrew-tap.

Expected layout:

```
AdrianLSY/homebrew-tap/
├── Casks/aerospace-adrianlsy.rb     # updated by release workflow
├── README.md
└── (optional) pin.sh                # version-pinning helper
```

**Setup:**

1. Create the repo as public.
2. Add `README.md` pointing at `AdrianLSY/AeroSpace` and giving the
   `brew tap AdrianLSY/tap && brew install --cask aerospace-adrianlsy`
   instructions.
3. Generate a GitHub PAT (fine-grained, scoped to `AdrianLSY/homebrew-tap`
   with `contents: write` and `pull_requests: write`), add it to
   `AdrianLSY/AeroSpace`'s repo secrets as `HOMEBREW_TAP_PAT`. The
   release workflow uses this to push the cask branch and open the PR.

## Docs site (GitHub Pages)

- Pages source = GitHub Actions. URL:
  https://adrianlsy.github.io/AeroSpace.
- Deploys only on tagged releases (`v*-Beta.adrianlsy.*`) — docs match a
  shipping version rather than chasing `main`.
- To preview doc changes locally: `./build-docs.sh && open .site/guide.html`.
- Enable Pages once: repo Settings → Pages → Source: "GitHub Actions".

## Upstream sync cadence

No fixed schedule. Rebase when:

- Upstream ships a release you want to incorporate.
- An upstream fix affects fork users.
- Accumulated upstream delta is approaching a rebase-complexity threshold
  (more than ~20 commits tends to make conflict resolution tedious).

After every rebase:

1. Re-run `./test.sh` before cutting a fork release — upstream changes
   can interact with AutoRaise (focus lifecycle, refresh session, command
   dispatch, config parsing).
2. Skim `CLAUDE.md` for accuracy — upstream renames/moves of subsystems
   can stale fork-specific architecture notes.
3. If upstream introduced a new file that overlaps with fork territory
   (e.g. another issue template, another workflow), update the conflict
   set table above.
