# Development Notes

To build/install from sources do the following:
1. Install dependencies
2. Create codesign certificate in `Keychain Access.app`
3. Run one of the entry point scripts to build/install from sources

Feel free to report GitHub issues if something doesn't work for you

If you struggle to build AeroSpace locally, you can also refer to [builds in GitHub Actions](https://github.com/nikitabobko/AeroSpace/actions?query=branch%3Amain)

## 1. Install dependencies

Install Xcode from App Store https://apps.apple.com/us/app/xcode/id497799835

If you want to build shell completion, install rust, bash and fish
- Install Rust using rustup. https://www.rust-lang.org/tools/install
- `brew install bash fish`

If you want to build man pages, install Ruby >= 3.0. I recommend using [rbenv](https://github.com/rbenv/rbenv).
- `rbenv install 3.3.4` (or whatever 3.x version)
- Install asciidoctor using Ruby `bundler`. `cd AeroSpace && bundler install`

Install optional `xcbeautify` to make Xcode build logs readable. `brew install xcbeautify`

## 2. Create codesign certificate

Before you can build the project you need to create self-signed certificate that will be used to codesign AeroSpace.
Signing the binary is required to preserve accessibility permission across rebuilds.

1. Open `Keychain Access.app`
2. Menu -> `Keychain Access` -> `Certificate Assistance` -> `Create a Certificate...`
   - Name: `aerospace-codesign-certificate`
   - Identity Type: `Self-Signed Root`
   - Certificate Type: `Code Signing`

## 3. Entry point scripts

**Debug build**
- `build-debug.sh` - Build debug build to `.debug` dir
- `run-tests.sh` - Run tests
- `run-debug.sh` - Run debug build of AeroSpace.app. It might be better to run debug build from Xcode.
- `run-cli.sh` - Run `aerospace` in CLI. Arguments are forwarded to `aerospace` binary
- `build-docs.sh` - Build the site and man pages to `.site` and `.man` dirs respectively
- `build-shell-completion.sh` - Build shell completion to `.shell-completion`
- `generate.sh` - Regenerate generated project files. `AeroSpace.xcodeproj` is generated, and some of the source files
  (the source files have `Generated` suffix in their names)

> [!IMPORTANT]
> Debug build uses `~/.aerospace-debug.toml` instead of `~/.aerospace.toml`

**Release build**
- `build-release.sh` - Build release build to `.release` dir
- `install-release.sh` - Build and install release build to `/Applications/AeroSpace.app` and `~/.bin/aerospace`

## IDE

- You can open the project in Xcode (open `AeroSpace.xcodeproj`)
- You can use your editor of choice (Neovim, Vim, Emacs, VS Code, Sublime) by using [sourcekit-lsp LSP](https://github.com/apple/sourcekit-lsp).
  I only tested it in Neovim
- AppCode. The initial codebase was written in AppCode and the IDE was pretty solid.
  But AppCode was unfortunately sunsetted, and it started falling apart.
  Last time I checked it, it didn't support Swift 5.9 features, and I couldn't make it reliably import the project.

## Tips

- Use built-in "Accessibility Inspector.app" to inspect accessibility properties of windows
- Use [BetterDisplay 2](https://github.com/waydabber/BetterDisplay) to emulate several monitors
- You can use `script/clean-project.sh` to clean the project when something goes wrong.
