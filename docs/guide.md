# AeroSpace Guide

**Table of contents**

- [Tree](#tree)
  - [Layouts](#layouts)
  - [Normalization](#normalization)
  - [Floating windows](#floating-windows)
- [Default keybindings](#default-keybindings)
- [Configuring AeroSpace](#configuring-aerospace)
  - [Binding modes](#bindings-modes)
  - [Commands](#commands)
- [Emulation of virtual workspaces](#emulation-of-virtual-workspaces)
  - [A note on mission control](#a-note-on-mission-control)
  - [A note on 'Displays have separate Spaces'](#a-note-on-displays-have-separate-spaces)
- [Multiple displays](#multiple-displays)

## Tree

AeroSpace stores all windows and containers in a tree. AeroSpace tree tiling model is [inspired by
i3](https://i3wm.org/docs/userguide.html#tree).

- Each workspace contains its own single root node
- Each non-leaf node can contain arbitrary number of children nodes
- Windows are the only possible leaf nodes. Windows contain zero children nodes
- Every non-leaf node has two properties:
  1. [Layout](#layouts) (Possible values: `list`, `accordion`)
  2. Orientation (Possible values: `horizontal`, `vertical`)

When we say "layout of the window", we refer to the layout of the window's parent.

It's easier to understand tree tiling model by looking at examples

![](./.assets/h_list.png)
![](./.assets/tree.png)

You can nest containers as deeply as you want to.

You can navigate in the tree in 4 possible cardinal directions (left, down, up, right). You use [focus
command](./commands.md#focus) to navigate in the tree.

The tree structure can be changed with two commands:
- [move-through](./commands.md#move-through)
- [join-with](./commands.md#join-with)

### Layouts

In total, AeroSpace provides 4 possible layouts:
- horizontal list (in i3, it's called "horizontal split")
- vertical list (in i3, it's called "vertical split")
- horizontal accordion (analog of i3's "tabbed layout")
- vertical accordion (analog of i3's "stacked layout")

From the previous section, you're already familiar with the List layout.

Accordion is a layout where windows are placed on top of each other.
- The horizontal accordion shows left and right paddings to visually indicate the presence of other windows in those directions.
- The vertical accordion shows top and bottom paddings to visually indicate the presence of other windows in those directions.

Horizontal accordion looks like this

<img src="./.assets/h_accordion.png" width="60%" height="60%">

Vertical accordion looks like this

<img src="./.assets/v_accordion.png" width="60%" height="60%">

Just like in a list layout, you can use the [focus](./commands.md#focus) command to navigate an accordion layout.

You can navigate the windows in an `h_accordion` by using the `focus (left|right)` command, while in a `v_accordion`, you can
navigate the windows using the `focus (up|down)` command.

Accordion padding is configurable via `accordion-padding` option (see [default-config.toml](../config-examples/default-config.toml))

### Normalization

By default, AeroSpace does two types of tree normalizations:
- Containers that have only one child are "flattened". Configured by `enable-normalization-flatten-containers`
- Containers that nest into each other must have opposite orientations. Configured by
  `enable-normalization-opposite-orientation-for-nested-containers`

**Example 1**

According to the first normalization, such layout isn't possible:
```
h_list
└── v_list
    └── window 1
```

it will be immediately transformed into
```
v_list
└── window 1
```

**Example 2**

According to the second normalization, such layout isn't possible:
```
h_list
├── window 1
└── h_list
    ├── window 2
    └── window 3
```

it will be immediately transformed into
```
h_list
├── window 1
└── v_list
    ├── window 2
    └── window 3
```

Normalizations makes it easier to understand the tree structure by looking at how windows are placed on the screen.

You can disable normalizations by placing these lines into your config:
```
enable-normalization-flatten-containers = false
enable-normalization-opposite-orientation-for-nested-containers = false
```

### Floating windows
TODO DOCUMENTATION

Normally, floating windows are not part of the tiling tree. But it's not the case with `focus` command. From `focus` command
perspective, floating windows are part of the tree. 

## Default keybindings

TODO DOCUMENTATION the idea behind default keybindings

## Configuring AeroSpace

AeroSpace will read config file from `~/.aerospace.toml`. Please see the following config samples:
- The default config contains all possible keys with comments: [default-config.toml](../config-examples/default-config.toml)
- i3 like config: [i3-like-config-example.toml](../config-examples/i3-like-config-example.toml)

AeroSpace uses TOML format for the config. TOML is easy to read, and it supports comments. See [TOML site for more
info](https://toml.io/en/)

### Binding modes
TODO DOCUMENTATION. For now you can refer to https://i3wm.org/docs/userguide.html#binding_modes

### Commands

AeroSpace is controlled by commands. For more info see [the list of all available commands](./commands.md).

## Emulation of virtual workspaces

The supposed workflow is to only have one macOS Space (or as many as monitors you have) and don't interact with macOS spaces in
any way

When user quits AeroSpace or before crashing, AeroSpace puts windows back to the center of the screen

### A note on mission control
TODO DOCUMENTATION
Enable 'Group windows by application'

### A note on 'Displays have separate Spaces'

AeroSpace doesn't care about `System Settings -> Desktop & Dock -> Displays have separate Spaces` setting. It works equally good
whether this option is turned off or on.

Overview of 'Displays have separate Spaces'

|                                                             | 'Displays have separate Spaces' is enabled | 'Displays have separate Spaces' is disabled |
|-------------------------------------------------------------|--------------------------------------------|---------------------------------------------|
| When the first display is in fullscreen                     | 😊 Second monitor operates independently   | 😔 Second monitor is unusable black screen  |
| Is it possible to place a window on the border of monitors? | 😔 No                                      | 😊 Yes                                      |
| macOS status bar ...                                        | ... is displayed on both monitors          | ... is displayed only on main monitor       |


## Multiple displays
TODO DOCUMENTATION
TODO DOCUMENTATION. Add difference with i3

