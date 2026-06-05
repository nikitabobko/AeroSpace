# FlightDeck

FlightDeck is an i3-like tiling window manager for macOS.

> [!NOTE]
> FlightDeck is a fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace) by [Nikita Bobko](https://github.com/nikitabobko).
> This project is not affiliated with or endorsed by the original AeroSpace project.

## Documentation

For usage and configuration details, see the official [AeroSpace documentation](https://nikitabobko.github.io/AeroSpace/guide).

## Key features

- Tiling window manager based on a tree paradigm
- i3-inspired
- Fast workspace switching without animations and without the necessity to disable SIP
- Plain text configuration for dotfiles-friendly setup
- CLI first, with manpages and shell completion included
- Proper multi-monitor support

## Development

Project setup, build instructions, and test details are available in [dev-docs/development.md](./dev-docs/development.md).

## Distribution

FlightDeck is Developer ID-signed, notarized by Apple, and distributed through [`saadjs/homebrew-tap`](https://github.com/saadjs/homebrew-tap).

## GitHub Actions release

The `release` workflow builds, signs, notarizes, staples, uploads `FlightDeck-v<version>.zip` to the matching GitHub release, and commits `Casks/flightdeck.rb` to `saadjs/homebrew-tap`.

Configure these repository secrets before running it:

- `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`: base64-encoded Developer ID Application `.p12`
- `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`: `.p12` export password
- `APPLE_KEYCHAIN_PASSWORD`: temporary CI keychain password
- `APPLE_ID`: Apple Developer account email
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization
- `HOMEBREW_TAP_TOKEN`: GitHub token with write access to `saadjs/homebrew-tap`

Run it manually with a version such as `1.0.0`, or push a tag named `v<version>`.

## Project values

**Values**
- Targeted at advanced users and developers
- Keyboard centric
- Breaking changes to configuration files, CLI behavior, and runtime behavior are avoided when possible
- No GUI for configuration
- Practical features over cosmetic features
- Avoid private APIs, code injection, and other brittle integrations as much as possible

**Non Values**
- Playing nicely with every existing macOS window-management feature
- Visual customization beyond practical integrations

## macOS compatibility table

|                                                                                | macOS 13 (Ventura) | macOS 14 (Sonoma) | macOS 15 (Sequoia) | macOS 26 (Tahoe) |
| ------------------------------------------------------------------------------ | ------------------ | ----------------- | ------------------ | ---------------- |
| FlightDeck binary runs on ...                                                  | +                  | +                 | +                  | +                |
| FlightDeck debug build from sources is supported on ...                        |                    | +                 | +                  | +                |
| FlightDeck release build from sources is supported on ... (Requires Xcode 26+) |                    |                   | +                  | +                |

## Related projects

- [Amethyst](https://github.com/ianyh/Amethyst)
- [yabai](https://github.com/koekeishiya/yabai)
