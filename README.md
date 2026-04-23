# Aeroshift

<img src="./resources/Assets.xcassets/AppIcon.appiconset/icon.png" width="40%" align="right">

Aeroshift is an unofficial fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace), the i3-like tiling window manager for macOS.

## Install

```bash
brew tap boredphilosopher96/aeroshift
brew install --cask aeroshift
```

## Docs

- [Guide](./docs/guide.adoc)
- [Commands](./docs/commands.adoc)
- [Goodies](./docs/goodies.adoc)
- [Development Notes](./dev-docs/development.md)

## Build From Source

To build Aeroshift locally:

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

## Support

Please use Discussions here first:

- [Aeroshift Discussions](https://github.com/Boredphilosopher96/Aeroshift/discussions)

If an issue also reproduces in upstream [AeroSpace](https://github.com/nikitabobko/AeroSpace), mention that in the report.
