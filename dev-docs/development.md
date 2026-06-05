# Development Notes

To build/install from sources do the following:
1. Install dependencies
2. Create codesign certificate in `Keychain Access.app`
3. Run one of the entry point scripts to build/install from sources

FlightDeck tracks upstream AeroSpace closely. When diagnosing an upstream build issue, the [AeroSpace GitHub Actions history](https://github.com/nikitabobko/AeroSpace/actions?query=branch%3Amain) may provide useful context.

## Definitions

**SPM.** Swift package manager and Swift build tool. In other words, `swift` CLI tool

## 1. Install dependencies

1.  Install Xcode from App Store https://apps.apple.com/us/app/xcode/id497799835
2.  Install [swiftly](https://github.com/swiftlang/swiftly).
    Swiftly is a Swift toolchain manager that will make sure that you use the same swift version as written in `.swift-version` file.
    `brew install swiftly`
3.  If you want to build shell completion, install rust, bash and fish
    -   Install Rust using rustup. https://www.rust-lang.org/tools/install
    -   `brew install bash fish`
4.  If you want to regenerate the shell parser, install Java.
    -   `brew install openjdk`
    -   If you use Homebrew OpenJDK, make sure `/opt/homebrew/opt/openjdk/bin` is on `PATH` before running `generate.sh`.
5.  If you want to build man pages, install Ruby >= 3.0 and < 5.0.
    -   `brew install ruby`
    -   Install asciidoctor using Ruby `bundler`. `cd FlightDeck && bundler install`
6.  Install optional `xcbeautify` to make Xcode build logs readable. `brew install xcbeautify`

## 2. Create codesign certificate

If you want to run FlightDeck as an app bundle, you need to create a self-signed certificate that will be used to codesign FlightDeck.
Release artifact is built as App Bundle.
If you only plan to build the debug version of FlightDeck, you can run it from the terminal and a custom certificate is not required.

1.  Open `Keychain Access.app`
2.  Menu -> `Keychain Access` -> `Certificate Assistance` -> `Create a Certificate...`
    -   Name: `flightdeck-codesign-certificate`
    -   Identity Type: `Self-Signed Root`
    -   Certificate Type: `Code Signing`

## 3. Entry point scripts

**Debug build**
-   `build-debug.sh` - Build debug build to `.debug` dir by using SPM. (Xcode is not involved)
-   `test.sh` - Run tests.
-   `swiftformat.sh` - Format the code.
-   `run-debug.sh` - Run the FlightDeck debug app.
-   `run-cli.sh` - Run `flightdeck` in CLI. Arguments are forwarded to the `flightdeck` binary.
-   `build-docs.sh` - Build the site and man pages to `.site` and `.man` dirs respectively.
-   `build-shell-completion.sh` - Build shell completion to `.shell-completion`.
    You can test that the completion works properly by sourcing the file `source ./.shell-completion/zsh/_flightdeck`
-   `generate.sh` - Regenerate generated project files. `AeroSpace.xcodeproj` is generated, and some of the source files
    (the source files have `Generated` suffix in their names).

**Release build**
-   `build-release.sh` - Build release build to `.release` dir by using Xcode.
-   `install-from-sources.sh` - Build release build from sources and install it as the `flightdeck-dev` brew cask.
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

1.  To open the project in Xcode: File -> Open -> Choose `Package.swift` file instead of `AeroSpace.xcodeproj`.
    It's better to open `Package.swift`, because SPM project is more lightweight.
    `AeroSpace.xcodeproj` is only used in `*release*.sh` build scripts.
2.  After you opened the project in Xcode.
    Edit Scheme... -> Options -> Console -> Choose `Terminal`.
    This way Accessibility permission will be requested from Terminal.
    If you don't change Console to `Terminal`, Accessibility permission will be requested on every rebuild, because the debug binary is unsigned.

## Tips

- Use built-in "Accessibility Inspector.app" to inspect accessibility properties of windows
- Use [DeskPad](https://github.com/Stengo/DeskPad) or [BetterDisplay 2](https://github.com/waydabber/BetterDisplay) to emulate several monitors
- You can use `script/clean-project.sh` to clean the project when something goes wrong.
