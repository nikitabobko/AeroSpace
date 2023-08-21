# AeroSpace [![Xcode - Build and Analyze](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/nikitabobko/AeroSpace/actions/workflows/build.yml)

AeroSpace is a tiling window manager for macOS.

## Key features

- **Manual** tiling window manager
- [i3](https://i3wm.org/) inspired
- AeroSpace employs its **own emulation of virtual workspaces** instead of relying on native macOS Spaces due to
  their considerable limitations
- Plain text configuration (dotfiles friendly)
- CLI scriptable
- Doesn't require disabling SIP (System Integrity Protection)
- Proper multi-monitor support (i3-like paradigm)
- Status menu icon displays current workspace name

## How to build the project

You would need a mac. Run in terminal:
```bash
./build.sh
```

## Todo

- subscribe to windows changes (new windows are opened, existing are closed)
- move window to another monitor (spaces? treat spaces as monitors)
- mouse resize events
- mouse move window events
- is dialog, is resizable, is modal?
- select parent and kill several windows at once
- select parent -> outline several windows?
  - OR: outline with "SLSSetWindowOpacity"
  - OR: "shake" windows
- CLI interface
- Check all todos in code
- move vs swap (swap requires position and size proportions decoupling from windows)
- what is src/Assets.xcassets ?

## Tests

- Test main monitor change
- Test monitor add/remove

## Challenges

- Window overlapping
- "floating" window layout
- windows' min/max sizes

## Known Special windows to check

- XCode welcome screen
- Finder preview
- Toolbox window
- IntelliJ dialog windows (e.g. "Add to git")
- IntelliJ project structure modal window
- VLC full screen window (eh, I wish every fullscreen window in macOS worked like that)

## Limitations of macOS API

- It's not possible to find to what monitor window is assigned
- It's not possible to __reliably__ know what monitor is currently active