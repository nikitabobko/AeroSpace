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
