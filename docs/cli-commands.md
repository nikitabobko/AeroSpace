# CLI commands

In addition to [regular commands](./commands.md), the CLI provides commands listed in this file

**Table of contents**
- [list-apps](#list-apps)
- [version](#version)

## list-apps

```
list-apps
```

Prints the list of ordinary applications that appears in the Dock and may have a user interface.

Output format is the table with the following colums:
- Process ID
- Application ID
- Application name

Output example:
```
486   com.apple.finder            Finder
17966 org.alacritty               Alacritty
24780 com.jetbrains.AppCode       AppCode
32541 com.apple.systempreferences System Settings
```

The command is useful to inspect list of applications to compose filter for [`on-window-detected`](./guide.md#on-window-detected-callback)

- Available since: 0.6.0-Beta
- The command doesn't have arguments

## version

```
version
--version
-v
```

Prints the version and commit hash to stdout

- Available since: 0.4.0-Beta
- The command doesn't have arguments
