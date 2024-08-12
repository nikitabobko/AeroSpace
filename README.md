 <img src="./xcode-app-bundle-launcher/Assets.xcassets/AppIcon.appiconset/icon.png" width="40%" height="40%" align="right">

# AeroSpace Beta [![Build](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml)

AeroSpace is an i3-like tiling window manager for macOS

Videos:
- [YouTube Short 91s Demo](https://www.youtube.com/watch?v=UOl7ErqWbrk)
- [YouTube Guide by Josean Martinez](https://www.youtube.com/watch?v=-FoWClVHG5g)

Docs:
- [AeroSpace Guide](https://nikitabobko.github.io/AeroSpace/guide)
- [AeroSpace Commands](https://nikitabobko.github.io/AeroSpace/commands)
- [AeroSpace Config Examples](https://nikitabobko.github.io/AeroSpace/config-examples)
- [AeroSpace Goodness](https://nikitabobko.github.io/AeroSpace/goodness)

## Project status

Public Beta. Feedback is very much welcome

- I encourage you to try AeroSpace and file GitHub issues if something doesn't work for you
- I already use AeroSpace on daily basis and I'm happy with it
- [The documentation](https://nikitabobko.github.io/AeroSpace/guide) covers all major things you need to know

## Key features

- Tiling window manager based on a [tree paradigm](https://nikitabobko.github.io/AeroSpace/guide#tree)
- [i3](https://i3wm.org/) inspired
- Fast workspaces switching without animations and without the necessity to disable SIP
- AeroSpace employs its [own emulation of virtual workspaces](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces) instead of relying on native macOS Spaces due to [their considerable limitations](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces)
- Plain text configuration (dotfiles friendly). See: [default-config.toml](https://nikitabobko.github.io/AeroSpace/config-examples#default-config)
- CLI first (manpages and shell completion included)
- Doesn't require disabling SIP (System Integrity Protection)
- [Proper multi-monitor support](https://nikitabobko.github.io/AeroSpace/guide#multiple-monitors) (i3-like paradigm)

## Installation

Install via [Homebrew](https://brew.sh/) to get autoupdates (Preferred)

```
brew install --cask nikitabobko/tap/aerospace
```

**(Optional)**
You might need to configure your shell to enable completion provided by homebrew packages: https://docs.brew.sh/Shell-Completion
AeroSpace provides bash, fish and zsh completions.

You can also install specific previous versions:
```
brew install --cask nikitabobko/tap/aerospace@0.12.0
```

For the list of all the versions available for installation via brew see: https://github.com/nikitabobko/homebrew-tap/tree/main/Casks

[Manual installation](https://nikitabobko.github.io/AeroSpace/guide#manual-installation)

> [!NOTE]
> By using AeroSpace, you acknowledge that it's not [notarized](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution).
>
> Notarization is a "security" feature by Apple.
> You send binaries to Apple, and they either approve the binaries or not.
> In reality, notarization is about building binaries the way Apple likes it.
>
> Let's be honest.
> Tiling window manager is not something Apple will be totally ok with.
> Even if they approve one version, it doesn't mean that they won't revoke it (yes, they can do it), or approve further versions.
>
> I don't have anything against notarization as a concept.
> I specifically don't like the way Apple does notarization.
> I don't have time to fight Apple.
>
> [Homebrew installation script](https://github.com/nikitabobko/homebrew-tap/blob/main/Casks/aerospace.rb) is configured to
> automatically delete `com.apple.quarantine` attribute, that's why the app should work out of the box, without any warnings that
> "Apple cannot check AeroSpace for malicious software"

## Contributing, creating issues, submitting pull requests

See: [CONTRIBUTING.md](./CONTRIBUTING.md)

## Development

A notes on how to setup the project, build it, how to run the tests, etc. can be found here: [dev-docs/development.md](./dev-docs/development.md)

## Values of the project

**Values**
- AeroSpace is targeted at advanced users and developers
- Keyboard centric
- Breaking changes (configuration files, CLI, behavior) are avoided as much as possible, but it must not let the software stagnate.
  Thus breaking changes can happen, but with careful considerations and helpful message.
  [Semver](https://semver.org/) major version is bumped in case of a breaking change (It's all guaranteed once AeroSpace reaches 1.0 version, until then breaking changes just happen)
- AeroSpace doesn't use GUI, unless necessarily
  - AeroSpace will never provide a GUI for configuration.
    For advanced users, it's easier to edit a configuration file in text editor rather than navigating through checkboxes in GUI.
  - Status menu icon is ok, because visual feedback is needed
- Provide _practical_ features. Fancy appearance features are not _practical_ (e.g. window borders, transparency, etc)
- If "dark magic" (aka "private APIs", "code injections", etc) can be avoided, it must be avoided
  - Right now, AeroSpace uses only a single private API to get window ID of accessibility object `_AXUIElementGetWindow`.
    Everything else is [macOS public accessibility API](https://developer.apple.com/documentation/applicationservices/axuielement_h).
  - AeroSpace will never require you to disable SIP (System Integrity Protection). For example, yabai [requires you to disable SIP](https://github.com/koekeishiya/yabai/issues/1863) to use some of its features.
    AeroSpace will either find another way (such as [emulation of workspaces](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces)) or will not implement this feature at all (window transparency and window shadowing are not _practical_ features)

**Non Values**
- Play nicely with existing macOS features. If limitations are imposed then AeroSpace won't play nicely with existing macOS features
  - E.g. AeroSpace doesn't acknowledge the existence of macOS Spaces, and it uses [emulation of its own workspaces](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces)

## Tip of the day

```bash
defaults write -g NSWindowShouldDragOnGesture YES
```

Now, you can move windows by holding `ctrl`+`cmd` and dragging any part of the window (not necessarily the window title)

Source: [reddit](https://www.reddit.com/r/MacOS/comments/k6hiwk/keyboard_modifier_to_simplify_click_drag_of/)

## Related projects
- [Amethyst](https://github.com/ianyh/Amethyst)
- [yabai](https://github.com/koekeishiya/yabai)
