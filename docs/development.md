# Development Notes

TLDR use `build-debug.sh`, `run-debug.sh`, and `run-tests.sh` scripts.

## Build Dependencies

The dependencies that are required to build AeroSpace:
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [xcbeautify](https://github.com/cpisciotta/xcbeautify)
- [GNU sed](https://www.gnu.org/software/sed/)
- [Asciidoctor](https://asciidoctor.org/)

```bash
brew install xcodegen gsed asciidoctor xcbeautify
```

## Create codesign certificate

Before you can build the project you need to create self-signed certificate that will be used to codesign AeroSpace.
Signing the binary is required to preserve accessibility permission across rebuilds.

1. Open `Keychain Access.app`
2. Menu -> `Keychain Access` -> `Certificate Assistance` -> `Create a Certificate...`
   - Name: `aerospace-codesign-certificate`
   - Identity Type: `Self-Signed Root`
   - Certificate Type: `Code Signing`

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
