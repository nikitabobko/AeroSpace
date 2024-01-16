# Development Notes

TLDR use `build-debug.sh`, `run-debug.sh`, and `run-tests.sh` scripts.

## Build Dependencies

The dependencies that are required to build AeroSpace:
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [GNU sed](https://www.gnu.org/software/sed/)
- [Asciidoctor](https://asciidoctor.org/)

```bash
brew install xcodegen gsed asciidoctor
```

## Setup Signing

Before you can build the project you need to setup signing. Signing the binary is required to preserve accessibility permission
across rebuilds.

```bash
cat <<EOF > .local.xcconfig
DEVELOPMENT_TEAM = XXXXXXXXXX
CODE_SIGN_IDENTITY = Apple Development
EOF
```

where `XXXXXXXXXX` is your signature ID. The easiest way to know your `DEVELOPMENT_TEAM` id is to [set the Team in Xcode
GUI](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app/) and see the `git diff`

## Debug Build

- `build-debug.sh` - Build debug build to `.debug` dir
- `run-tests.sh` - Run tests
- `run-debug.sh` - Run debug build of AeroSpace.app
- `run-cli.sh` - Run `aerospace` in CLI. Arguments are forwarded to `aerospace` binary
- `build-docs.sh` - Build the site and manpages to `.site` and `.man` dirs respectively
- `generate.sh` - Regenerate generated project files. `AeroSpace.xcodeproj` is generated, and some of the source files
  (the source files have `Generated` suffix in their names)

> [!IMPORTANT]
> Debug build uses `~/.aerospace-debug.toml` instead of `~/.aerospace.toml`

## Release Build

- `build-release.sh` - Build release build to `.release` dir
- `install-release.sh` - Build and install release build to `/Applications/AeroSpace.app` and `~/.bin/aerospace`

## Tips

- Use built-in "Accessibility Inspector.app" to inspect accessibility properties of windows
- Use [BetterDisplay 2](https://github.com/waydabber/BetterDisplay) to emulate several monitors
- You can use `script/clean-project.sh` to clean the project when something goes wrong.
