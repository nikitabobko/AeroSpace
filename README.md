# Aeroshift

<img src="./resources/Assets.xcassets/AppIcon.appiconset/icon.png" width="40%" align="right">

Aeroshift is an unofficial fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace), the i3-like tiling window manager for macOS.

User-facing artifacts from this repository use:

- `Aeroshift.app`
- `aeroshift`
- `~/.aeroshift.toml`
- `~/.config/aeroshift/aeroshift.toml`
- `aeroshift` and `aeroshift-dev` casks

## Docs

- [Guide](./docs/guide.adoc)
- [Commands](./docs/commands.adoc)
- [Goodies](./docs/goodies.adoc)
- [Development Notes](./dev-docs/development.md)

## Installation

To work on this repository locally:

```bash
mise install
mise run setup
mise run build
```

To run the full local validation path for this repository:

```bash
mise run test
mise run docs
mise run completions
mise run release-ci
```

Release artifacts are published as `Aeroshift` and `aeroshift`.

The Homebrew tap for this project lives at [Boredphilosopher96/homebrew-aeroshift](https://github.com/Boredphilosopher96/homebrew-aeroshift). Install instructions will be added here once the first tagged Aeroshift release is published there.

## Support

Please use Discussions here first:

- [Aeroshift Discussions](https://github.com/Boredphilosopher96/Aeroshift/discussions)

If an issue also reproduces in upstream [AeroSpace](https://github.com/nikitabobko/AeroSpace), mention that in the report.
