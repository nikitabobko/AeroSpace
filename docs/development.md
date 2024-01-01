# Development notes

TLDR see `build-debug.sh`, `run-debug.sh`, and `run-tests.sh` scripts.

## Debug build

**Dependencies**

The dependencies that are required to build AeroSpace:
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [GNU sed](https://www.gnu.org/software/sed/)
- [Asciidoctor](https://asciidoctor.org/)
- [tree](https://oldmanprogrammer.net/source.php?dir=projects/tree)

```bash
brew install xcodegen gsed asciidoctor tree
```

**Entry point scripts**

- `build-debug.sh` - Build debug build to `.debug` dir
- `run-tests.sh` - Run tests
- `run-debug.sh` - Run debug build of AeroSpace.app
- `run-cli.sh` - Run `aerospace` in CLI. Arguments are forwarded to `aerospace` binary
- `build-docs.sh` - Build the site and manpages to `.site` and `.man` dirs respectively
- `generate.sh` - Regenerate generated project files. `AeroSpace.xcodeproj` is generated, and some of the source files
  (the source files have `Generated` suffix in their names)

> [!IMPORTANT]
> Debug build uses `~/.aerospace-debug.toml` instead of `~/.aerospace.toml`

## Release build

**Signing**

1. Change `DEVELOPMENT_TEAM` in `project.yml`
2. Run `generate.sh` script

The easiest way to know your `DEVELOPMENT_TEAM` id is to
[set the Team in Xcode GUI](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app/) and see the `git diff`

**Entry point scripts**

After you setup signing, you can build the release build:
- `build-release.sh` - Build release build to `.release` dir
- `install-release.sh` - Build and install release build to `/Applications/AeroSpace.app` and `~/.bin/aerospace`

## Caveats

- Signing the binary is required to preserve accessibility permission across rebuilds.
  `run-debug.sh` runs the AeroSpace.app on behalf of the terminal app, that's why it's not affected by this caveat.
- You can use `clean-project.sh` to clean the project when something goes wrong.

## Tips

- Use built-in "Accessibility Inspector.app" to inspect accessibility properties of windows
- Use [BetterDisplay 2](https://github.com/waydabber/BetterDisplay) to emulate several monitors
