 <img src="./resources/Assets.xcassets/AppIcon.appiconset/icon.png" width="40%" height="40%" align="right">

# AeroSpace Beta [![Build](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml)

AeroSpace is an i3-like tiling window manager for macOS

Videos:
- [YouTube 91 sec Demo](https://www.youtube.com/watch?v=UOl7ErqWbrk)
- [YouTube Guide by Josean Martinez](https://www.youtube.com/watch?v=-FoWClVHG5g)

Docs:
- [AeroSpace Guide](https://nikitabobko.github.io/AeroSpace/guide)
- [AeroSpace Commands](https://nikitabobko.github.io/AeroSpace/commands)
- [AeroSpace Goodies](https://nikitabobko.github.io/AeroSpace/goodies)

## Project status

Public Beta. AeroSpace can be used as a daily driver, but expect breaking changes until 1.0 is reached.

## Key features

- Tiling window manager based on a [tree paradigm](https://nikitabobko.github.io/AeroSpace/guide#tree)
- [i3](https://i3wm.org/) inspired
- Fast workspaces switching without animations and without the necessity to disable SIP
- AeroSpace employs its [own emulation of virtual workspaces](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces) instead of relying on native macOS Spaces due to [their considerable limitations](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces)
- Plain text configuration (dotfiles friendly). See: [default-config.toml](https://nikitabobko.github.io/AeroSpace/guide#default-config)
- CLI first (manpages and shell completion included)
- Doesn't require disabling SIP (System Integrity Protection)
- [Proper multi-monitor support](https://nikitabobko.github.io/AeroSpace/guide#multiple-monitors) (i3-like paradigm)

## Installation

Install via [Homebrew](https://brew.sh/) to get autoupdates (Preferred)

```
brew install --cask nikitabobko/tap/aerospace
```

In multi-monitor setup please make sure that monitors [are properly arranged](https://nikitabobko.github.io/AeroSpace/guide#proper-monitor-arrangement).

Other installation options: https://nikitabobko.github.io/AeroSpace/guide#installation

> [!NOTE]
> By using AeroSpace, you acknowledge that it's not [notarized](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution).
>
> Notarization is a "security" feature by Apple.
> You send binaries to Apple, and they either approve them or not.
> In reality, notarization is about building binaries the way Apple likes it.
>
> I don't have anything against notarization as a concept.
> I specifically don't like the way Apple does notarization.
> I don't have time to deal with Apple.
>
> [Homebrew installation script](https://github.com/nikitabobko/homebrew-tap/blob/main/Casks/aerospace.rb) is configured to
> automatically delete `com.apple.quarantine` attribute, that's why the app should work out of the box, without any warnings that
> "Apple cannot check AeroSpace for malicious software"

## Community, discussions, issues

Community discussions happen at GitHub Discussions.
There you can report bugs, propose new features, ask your questions, show off your setup, or just chat.

There are 7 channels:
-   [#all](https://github.com/nikitabobko/AeroSpace/discussions).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions.atom?discussions_q=sort%3Adate_created).
    Feed with all discussions.
-   [#announcements](https://github.com/nikitabobko/AeroSpace/discussions/categories/announcements).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/announcements.atom?discussions_q=category%3Aannouncements+sort%3Adate_created).
    Only maintainers can post here.
    Highly moderated traffic.
-   [#announcements-releases](https://github.com/nikitabobko/AeroSpace/discussions/categories/announcements-releases).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/announcements-releases.atom?discussions_q=category%3Aannouncements-releases+sort%3Adate_created).
    Announcements about non-patch releases.
    Only maintainers can post here.
-   [#feature-ideas](https://github.com/nikitabobko/AeroSpace/discussions/categories/feature-ideas).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/feature-ideas.atom?discussions_q=category%3Afeature-ideas+sort%3Adate_created).
-   [#general](https://github.com/nikitabobko/AeroSpace/discussions/categories/general).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/general.atom?discussions_q=sort%3Adate_created+category%3Ageneral).
-   [#potential-bugs](https://github.com/nikitabobko/AeroSpace/discussions/categories/potential-bugs).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/potential-bugs.atom?discussions_q=category%3Apotential-bugs+sort%3Adate_created).
    If you think that you have encountered a bug, you can report it here.
-   [#questions-and-answers](https://github.com/nikitabobko/AeroSpace/discussions/categories/questions-and-answers).
    [RSS](https://github.com/nikitabobko/AeroSpace/discussions/categories/questions-and-answers.atom?discussions_q=category%3Aquestions-and-answers+sort%3Adate_created).
    Everyone is welcome to ask questions.
    Everyone is encouraged to answer other people's questions.

You're welcome to submit bug reports and feature ideas in GitHub Discussions.
See: [CONTRIBUTING.md](./CONTRIBUTING.md)

## Development

A notes on how to setup the project, build it, how to run the tests, etc. can be found here: [dev-docs/development.md](./dev-docs/development.md)

## Project values

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
- Provide _practical_ features. Fancy appearance features are not _practical_ (e.g. window borders, transparency, animations, etc.)
- "dark magic" (aka "private APIs", "code injections", etc.) must be avoided as much as possible
  - Right now, AeroSpace uses only a single private API to get window ID of accessibility object `_AXUIElementGetWindow`.
    Everything else is [macOS public accessibility API](https://developer.apple.com/documentation/applicationservices/axuielement_h).
  - AeroSpace will never require you to disable SIP (System Integrity Protection).
  - The goal is to make AeroSpace easily maintainable, and resistant to macOS updates.

**Non Values**
- Play nicely with existing macOS features.
  If limitations are imposed then AeroSpace won't play nicely with existing macOS features
  (For example, AeroSpace doesn't acknowledge the existence of macOS Spaces, and it uses [emulation of its own workspaces](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces))
- Ricing.
  AeroSpace provides only a very minimal support for ricing - gaps and a few callbacks for integrations with bars.
  The current maintainer doesn't care about ricing.
  Ricing issues are not a priority, and they are mostly ignored.
  The ricing stance can change only with the appearance of more maintainers.

## Tip of the day

```bash
defaults write -g NSWindowShouldDragOnGesture -bool true
```

Now, you can move windows by holding `ctrl`+`cmd` and dragging any part of the window (not necessarily the window title)

Source: [reddit](https://www.reddit.com/r/MacOS/comments/k6hiwk/keyboard_modifier_to_simplify_click_drag_of/)

## Related projects
- [Amethyst](https://github.com/ianyh/Amethyst)
- [yabai](https://github.com/koekeishiya/yabai)
