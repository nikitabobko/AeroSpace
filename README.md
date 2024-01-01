<img src="./src/Assets.xcassets/AppIcon.appiconset/icon.png" width="40%" height="40%" align="right">

# AeroSpace Beta [![Build](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml)

AeroSpace is an i3-like tiling window manager for macOS

- [YouTube Demo](https://www.youtube.com/watch?v=UOl7ErqWbrk)
- [AeroSpace Guide](https://nikitabobko.github.io/AeroSpace/guide.html)
- [AeroSpace Commands](https://nikitabobko.github.io/AeroSpace/commands.html)
- [AeroSpace Config Examples](https://nikitabobko.github.io/AeroSpace/config-examples.html)
- [AeroSpace Goodness](https://nikitabobko.github.io/AeroSpace/goodness.html)

## Project status

Public Beta. Feedback is very much welcome

- I encourage you to try AeroSpace and file GitHub issues if something doesn't work for you.
  In particular, I'm interested in issues that block you from using AeroSpace on daily basis.
- I already use AeroSpace on daily basis and I'm happy with it
- [The documentation](https://nikitabobko.github.io/AeroSpace/guide.html) covers all major things you need to know
- Expect minor breaking changes in the config format. Once the project reaches 1.0 the config is guaranteed to preserve backwards
  compatibility

## Key features

- **Manual** tiling window manager based on a [tree paradigm](https://nikitabobko.github.io/AeroSpace/guide.html#tree)
- [i3](https://i3wm.org/) inspired
- AeroSpace employs
  its [own emulation of virtual workspaces](https://nikitabobko.github.io/AeroSpace/guide.html#emulation-of-virtual-workspaces)
  instead of relying on native macOS Spaces due
  to [their considerable limitations](https://nikitabobko.github.io/AeroSpace/guide.html#emulation-of-virtual-workspaces)
- Plain text configuration (dotfiles friendly). See: [default-config.toml](https://nikitabobko.github.io/AeroSpace/config-examples.html#default-config)
- ~~CLI scriptable~~ [[PLANNED]](https://github.com/nikitabobko/AeroSpace/issues/3)
- Doesn't require disabling SIP (System Integrity Protection)
- [Proper multi-monitor support](https://nikitabobko.github.io/AeroSpace/guide.html#multiple-monitors) (i3-like paradigm)
- Status menu icon displays current workspace name

## Installation

Install via [Homebrew](https://brew.sh/) to get autoupdates (Preferred)
```
brew install --no-quarantine --cask nikitabobko/tap/aerospace
```

[Manual installation](./docs/manual-installation.md)

## Development notes

A notes on how to setup the project, build it, how to run the tests, etc. can be found here: [docs/development.md](docs/development.md)

## Values of the project

**Values**
- AeroSpace is targeted at advanced users and developers
- Keyboard centric
- Never break configuration files (Guaranteed once AeroSpace reaches 1.0 version)
- AeroSpace doesn't use GUI, unless necessarily
  - AeroSpace will never provide a GUI for configuration. For advanced users, it's easier to edit a configuration file in text
    editor rather than navigating through checkboxes in GUI.
  - Status menu icon is ok, because visual feedback is needed
- Provide _practical_ features. Fancy appearance features are not _practical_ (e.g. window borders, transparency, etc)
- If "dark magic" (aka "private APIs", "code injections", etc) can be avoided, it must be avoided
  - Right now, AeroSpace uses only a [single private API to get window ID of accessibility object](./src/Bridged-Header.h).
    Everything else is [macOS public accessibility
    API](https://developer.apple.com/documentation/applicationservices/axuielement_h).
  - AeroSpace will never require you to disable SIP (System Integrity Protection). For example, yabai [requires you to disable
    SIP](https://github.com/koekeishiya/yabai/issues/1863) to use some of its features. AeroSpace will either find another way
    ( e.g. [emulation of workspaces](https://nikitabobko.github.io/AeroSpace/guide.html#emulation-of-virtual-workspaces))
    or will not implement this feature at all (window transparency and window shadowing are not _practical_ features)

**Non Values**
- Play nicely with existing macOS features. If limitations are imposed then AeroSpace won't play nicely with existing macOS
  features
  - E.g. AeroSpace doesn't acknowledge the existence of macOS Spaces, and it uses [emulation of its own
    workspaces](https://nikitabobko.github.io/AeroSpace/guide.html#emulation-of-virtual-workspaces)

## Tip of the day

```bash
defaults write -g NSWindowShouldDragOnGesture YES
```

Now, you can move windows by holding `ctrl`+`cmd` and dragging any part of the window (not necessarily the window title)

Source: [reddit](https://www.reddit.com/r/MacOS/comments/k6hiwk/keyboard_modifier_to_simplify_click_drag_of/)

## Related projects
- [Amethyst](https://github.com/ianyh/Amethyst)
- [yabai](https://github.com/koekeishiya/yabai)
