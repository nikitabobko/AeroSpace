# Title

## How to build the project

You would need a mac. Run in terminal:
```bash
xcodebuild
```

## Todo

- activate window
- resize window, position window
- hide window
- subscribe to windows changes (new windows are opened, existing are closed)
- move window to another monitor (spaces? treat spaces as monitors)
- mouse resize events
- mouse move window events
- is dialog, is resizable, is modal?
- close window (because you can select parent and kill several windows at once)
- select parent -> outline several windows?
- Handle visible Dock for maximized windows

## Features

- Scriptable from cli
- Own implementation of virtual workspaces (because native macOS "Spaces" desperately suck)

## Challenges

- Window overlapping
- "floating" window layout
- windows' min/max sizes

## Known Special windows

- macos welcome screen
- Toolbox window
- IntelliJ dialog windows (e.g. "Add to git")
- IntelliJ project structure modal window
