# AeroSpace [![Build](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml)

AeroSpace is a tiling window manager for macOS.

## Project status

Public Beta. Feedback is very much welcome

- I encourage you to try AeroSpace and [share the general feedback](https://github.com/nikitabobko/AeroSpace/issues/11).
  In particular, I'm interested in issues that block you from using AeroSpace.
- I already use AeroSpace on daily basis and I'm happy with it
- [The documentation](./docs/guide.md) covers all major things you need to know
- Expect minor breaking changes in the config format. Once the project reaches 1.0 the config is guaranteed to preserve backwards
  compatibility

## Key features

- **Manual** tiling window manager based on a [tree paradigm](./docs/guide.md#tree)
- [i3](https://i3wm.org/) inspired
- AeroSpace employs its [own emulation of virtual workspaces](./docs/guide.md#emulation-of-virtual-workspaces) instead of relying
  on native macOS Spaces due to [their considerable limitations](./docs/guide.md#emulation-of-virtual-workspaces)
- Plain text configuration (dotfiles friendly). See: [default-config.toml](./config-examples/default-config.toml)
- ~~CLI scriptable~~ [[PLANNED]](https://github.com/nikitabobko/AeroSpace/issues/3)
- Doesn't require disabling SIP (System Integrity Protection)
- [Proper multi-display support](./docs/guide.md#multiple-displays) (i3-like paradigm)
- Status menu icon displays current workspace name

## Installation

Install via Homebrew to get autoupdates (Preferred)
```
brew install --cask nikitabobko/tap/aerospace
xattr -d com.apple.quarantine /Applications/AeroSpace.app
```

### Manual installation

1. Download the latest available zip from [releases page](https://github.com/nikitabobko/AeroSpace/releases)
2. Unpack zip
3. Move unpacked `AeroSpace.app` to `/Applications`

If you see this message

> "AeroSpace.app" can't be opened because Apple cannot check it for malicious software.

then you can resolve it this way
```
xattr -d com.apple.quarantine /Applications/AeroSpace.app
```

or:
1. navigate in Finder to /Applications/AeroSpace.app
2. Right mouse click
3. Open (yes, it's that stupid)

## Docs

- [AeroSpace Guide](./docs/guide.md)
- [AeroSpace list of all commands](./docs/commands.md)

## How to build the project

You would need a Mac.

```bash
brew install xcodegen # https://github.com/yonaskolb/XcodeGen
./build-debug.sh
```

## How to run the tests

```bash
brew install xcodegen # https://github.com/yonaskolb/XcodeGen
./run-tests.sh
```

## Values of the project

**Values**
- AeroSpace is targeted at advanced users and developers
- Keyboard centric
- Never break configuration files (Guaranteed once AeroSpace reaches 1.0 version)
- AeroSpace doesn't use GUI, unless necessarily
  - AeroSpace will never provide a GUI for configuration. For advanced users, it's easier to edit a configuration file in text
    editor rather than navigating through checkboxes in GUI.
  - Status menu icon is ok, because visual feedback is needed
- Provide _practical_ features. Fancy appearance features are not _practical_
- If "dark magic" (aka "private APIs", "code injections", etc) can be avoided, it must be avoided
  - Right now, AeroSpace uses only a [single private API](./src/Bridged-Header.h). Everything else is [macOS public accessibility
    API](https://developer.apple.com/documentation/applicationservices/axuielement_h).
  - AeroSpace will never require you to disable SIP (System Integrity Protection). For example, yabai [requires you to disable
    SIP](https://github.com/koekeishiya/yabai/issues/1863) to use some of its features. AeroSpace will either find another way
    (e.g. [emulation of workspaces](./docs/guide.md#emulation-of-virtual-workspaces)) or will not implement this feature at all
    (window transparency and window shadowing are not _practical_ features)

**Non Values**
- Play nicely with existing macOS features. If limitations are imposed then AeroSpace won't play nicely with existing macOS
  features
  - E.g. AeroSpace doesn't acknowledge the existence of macOS Spaces, and it uses [emulation of its own
    workspaces](./docs/guide.md#emulation-of-virtual-workspaces)

## Tip of the day

```bash
defaults write -g NSWindowShouldDragOnGesture YES
```

Now, you can move windows by holding `ctrl`+`cmd` and dragging any part of the window (not necessarily the window title)

Source: [reddit](https://www.reddit.com/r/MacOS/comments/k6hiwk/keyboard_modifier_to_simplify_click_drag_of/)

## Related projects

If AeroSpace doesn't work for you, take a look at projects by other authors:
- [Amethyst](https://github.com/ianyh/Amethyst)
- [yabai](https://github.com/koekeishiya/yabai)