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

## Features

- Scriptable from cli
- Own implementation of virtual workspaces (because native macOS "Spaces" desperately suck)

## Challenges

- Window overlapping
- "floating" window layout
- windows' min/max sizes