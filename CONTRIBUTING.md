# Contributing

Aeroshift is an unofficial fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace). Keep that distinction explicit in code, docs, release assets, screenshots, and issue reports.

## Discussions First

Use Discussions in this fork before opening issues:

- [Aeroshift Discussions](https://github.com/Boredphilosopher96/Aeroshift/discussions)

Do not file fork-specific behavior against upstream [AeroSpace](https://github.com/nikitabobko/AeroSpace) unless you have reproduced it there too.

## Reporting Problems

When reporting a bug or proposing a feature for Aeroshift, include:

- `aeroshift debug-windows` output when the issue is window-specific
- relevant screenshots or videos
- your config
- Aeroshift version
- macOS version
- whether the behavior is fork-only or also reproducible in upstream [AeroSpace](https://github.com/nikitabobko/AeroSpace)

## Pull Requests

For non-trivial user-visible changes, start a Discussion in this fork first.

When sending a PR:

- use the `Aeroshift` and `aeroshift` names for all user-facing artifacts
- label upstream references as upstream
- call out any deliberate fork-only divergence from upstream [AeroSpace](https://github.com/nikitabobko/AeroSpace)
- keep commits scoped and coherent

## Local Validation

This repository uses `mise` as the repo-managed toolchain entry point:

```bash
mise install
mise run setup
mise run build
mise run test
mise run docs
mise run completions
mise run release-ci
```

## License

By contributing to this repository, you agree to license your contributions under the MIT license.
