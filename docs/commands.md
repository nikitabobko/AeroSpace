# Commands

**Table of contents**
- [close-all-windows-but-current](#close-all-windows-but-current)
- [exec-and-forget](#exec-and-forget)
- [exec-and-wait](#exec-and-wait)
- [flatten-workspace-tree](#flatten-workspace-tree)
- [focus](#focus)
- [layout](#layout)
- [mode](#mode)
- [move-container-to-workspace](#move-container-to-workspace)
- [move-in](#move-in)
- [move-through](#move-through)
- [move-workspace-to-display](#move-workspace-to-display)
- [reload-config](#reload-config)
- [resize](#resize)
- [workspace-back-and-forth](#workspace-back-and-forth)
- [workspace](#workspace)

## close-all-windows-but-current

```
close-all-windows-but-current
```

On the focused workspace, closes all windows but current. This command doesn't have any arguments.

## exec-and-forget

```
exec-and-forget bash_command
```

Runs `/bin/bash -c '$bash_command'`. Stdout, stderr and exit code are ignored.

For example, you can use this command to launch applications: `exec-and-forget open -n /System/Applications/Utilities/Terminal.app`

## exec-and-wait

```
exec-and-wait bash_command
```

Runs `/bin/bash -c '$bash_command'`, and waits until the command is terminated. Stdout, stderr and exit code are ignored.

Please prefer `exec-and-forget`, unless you need to wait for the termination.

You might want to wait for the termination if you have a list of commands, and you want `bash_command` to exit until you run the
next command.

Suppose that you have this binding in your config:
```toml
alt-enter = ['exec-and-wait open -n /System/Applications/Utilities/Terminal.app && sleep 1', 'layout floating']
```

It will open up Terminal.app and make it float. `sleep 1` is still required because `open` returns before the window appears.

## flatten-workspace-tree

```
flatten-workspace-tree
```

Flattens [the tree](./guide.md#tree) of currently focused workspace. This command doesn't have any arguments.

The command is useful when you messed up with your layout, and it's easier to "reset" it and start again.

## focus

```
focus (left|down|up|right)
```

Sets focus to the nearest window in [the tree](./guide.md#tree) in the given direction.

[Contrary to i3](https://i3wm.org/docs/userguide.html#_focusing_moving_containers), `focus` command doesn't have a separate
argument to focus floating windows. From `focus` command perspective, floating windows are part of [the tree](./guide.md#tree).
The floating window parent is determined as the smallest tiling container that contains the center of the floating window.

This technique eliminates the need for an additional binding for floating windows.

`focus child|parent` [isn't yet supported](https://github.com/nikitabobko/AeroSpace/issues/5) because of a low priority.

## layout

```
layout (h_list|v_list|h_accordion|v_accordion|list|accordion|horizontal|vertical|tiling|floating)...
```

Changes layout of the focused window to the given layout.

If several layouts are supplied then finds the first layout that doesn't describe the currently active layout, and applies the
found layout.

`layout tiling` is the only command that makes the focused floating window tiled.

## mode

```
mode name_of_the_target_mode
```

## move-container-to-workspace

## move-in

```
move-in (left|down|up|right)
```

Puts the currently focused window and the window in specified direction under one parent container

Given this layout
```
h_list
├── window 1
├── window 2 (focused)
└── window 3
```

`move-in right` will result in the following layout
```
h_list
├── window 1
└── v_list
    ├── window 2 (focused)
    └── window 3
```

## move-through

```
move-through (left|down|up|right) [floating_pixel]
```

Moves the window in the given direction. The optional `floating_pixel` argument specifies how far the window should be moved if
it is floating. The default is 50 pixels

This command is an analog of [i3's move command](https://i3wm.org/docs/userguide.html#move_direction)

**Example 1**

Given this layout
```
h_list
├── window 1 (focused)
└── window 2
```

`move-through right` will result in the following layout
```
h_list
├── window 2
└── window 1 (focused)
```

**Example 2**

Given this layout
```
h_list
├── window 1
├── window 2 (focused)
└── v_list
    ├── window 3
    └── window 4
```

`move-through right` will result in the following layout
```
h_list
├── window 1
└── v_list
    ├── window 3
    ├── window 2 (focused)
    └── window 4
```

**Example 3**

Given this layout
```
h_list
├── window 1
└── v_list
    ├── window 3
    ├── window 2 (focused)
    └── window 4
```

`move-through left` will result in the following layout
```
h_list
├── window 1
├── window 2 (focused)
└── v_list
    ├── window 3
    └── window 4
```

**Implicit container example**

In some cases, `move-through` needs to implicitly create a container to fullfill your command.

Given this layout
```
h_list
├── window 1
├── window 2 (focused)
└── window 3
```

`move-through up` will result in the following layout
```
v_list
├── window 2  (focused)
└── h_list
    ├── window 1
    └── window 3
```

`v_list` is an implicitly created container.

## move-workspace-to-display

## reload-config

## resize

## workspace-back-and-forth

## workspace
