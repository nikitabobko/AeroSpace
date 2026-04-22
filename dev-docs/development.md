# Development Notes

This repository builds the unofficial `Aeroshift` fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace). Keep the fork naming explicit in docs, screenshots, release assets, and user-facing strings.

To build/install from sources do the following:
1. Install dependencies
2. Create codesign certificate in `Keychain Access.app`
3. Run one of the entry point scripts to build/install from sources

If you struggle to build Aeroshift locally, you can also refer to [builds in this fork's GitHub Actions](https://github.com/Boredphilosopher96/Aeroshift/actions)

## Definitions

**SPM.** Swift package manager and Swift build tool. In other words, `swift` CLI tool

## 1. Install dependencies

1.  Install Xcode from App Store https://apps.apple.com/us/app/xcode/id497799835
2.  Install [mise](https://mise.jdx.dev/) on your machine.
    Aeroshift keeps its repo-managed toolchain in `mise.toml`, so local contributors and GitHub Actions use the same tool versions.
3.  From the repo root, install the repo toolchain with `mise install`.
    This installs the repo-managed Ruby, bundler, shell-completion generator, formatting/linting tools, and other CLI dependencies.
4.  Run `mise run setup`.
    This installs Ruby gems with bundler and regenerates the project files.
5.  Homebrew is still required only for `install-from-sources.sh`, because that script installs the generated local cask. The repo-managed toolchain itself is still installed by `mise install`.

## 2. Create codesign certificate

If you want to run Aeroshift as App Bundle (Aeroshift.app) you need to create self-signed certificate that will be used to codesign Aeroshift.
Release artifact is built as App Bundle.
If you only plan to build the debug version of Aeroshift, you can run it from the terminal and custom certificate is not required.

1.  Open `Keychain Access.app`
2.  Menu -> `Keychain Access` -> `Certificate Assistance` -> `Create a Certificate...`
    -   Name: `aeroshift-codesign-certificate`
    -   Identity Type: `Self-Signed Root`
    -   Certificate Type: `Code Signing`

## 3. Entry point scripts

Prefer the `mise` tasks as the public entry points:
-   `mise run setup`
-   `mise run build`
-   `mise run test`
-   `mise run docs`
-   `mise run format`
-   `mise run lint`
-   `mise run completions`
-   `mise run release`

The shell scripts below are the underlying implementation that those tasks run.

**Debug build**
-   `build-debug.sh` - Build debug build to `.debug` dir by using SPM. (Xcode is not involved)
-   `test.sh` - Run tests.
-   `format.sh` - Format the code.
-   `run-debug.sh` - Run Aeroshift.app debug build.
-   `run-cli.sh` - Run `aeroshift` in CLI. Arguments are forwarded to `aeroshift` binary.
-   `build-docs.sh` - Build the site and man pages to `.site` and `.man` dirs respectively.
-   `build-shell-completion.sh` - Build shell completion to `.shell-completion`.
    You can test that the completion works properly by sourcing the file `source ./.shell-completion/zsh/_aeroshift`
-   `generate.sh` - Regenerate generated project files. `Aeroshift.xcodeproj` is generated, and some of the source files
    (the source files have `Generated` suffix in their names).

**Release build**
-   `build-release.sh` - Build release build to `.release` dir by using Xcode.
-   `install-from-sources.sh` - Build release build from sources and install it as `aeroshift-dev` brew cask.
    This script is "work in progress".
    Use it on your own risk.

## IDE

-   You can obviously [open the project in Xcode](#xcode).
-   You can use your editor of choice (Neovim, Vim, Emacs, Sublime, VS Code) by using [sourcekit-lsp LSP](https://github.com/apple/sourcekit-lsp).
    I only tested it in Neovim
-   AppCode. The initial codebase was written in AppCode and the IDE was pretty solid.
    But AppCode was unfortunately sunsetted, and it started falling apart.
    Last time I checked it, it didn't support Swift 5.9 features, and I couldn't make it reliably import the project.
    RIP

## Xcode

Even if you use LSP and another text editor, Xcode is still useful to attach debugger (though you can use `lldb` in CLI).

1.  To open the project in Xcode: File -> Open -> Choose `Package.swift` file instead of `Aeroshift.xcodeproj`.
    It's better to open `Package.swift`, because SPM project is more lightweight.
    `Aeroshift.xcodeproj` is only used in `*release*.sh` build scripts.
2.  After you opened the project in Xcode.
    Edit Scheme... -> Options -> Console -> Choose `Terminal`.
    This way Accessibility permission will be requested from Terminal.
    If you don't change Console to `Terminal`, Accessibility permission will be requested on every rebuild, because the debug binary is unsigned.

## Tips

- Use built-in "Accessibility Inspector.app" to inspect accessibility properties of windows
- Use [DeskPad](https://github.com/Stengo/DeskPad) or [BetterDisplay 2](https://github.com/waydabber/BetterDisplay) to emulate several monitors
- You can use `script/clean-project.sh` to clean the project when something goes wrong.
