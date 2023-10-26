# AeroSpace Guide

**Table of contents**

- [Tree](#tree)
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
TODO DOCUMENTATION. This section is yet to be written, for now you can refer to https://i3wm.org/docs/userguide.html#tree

### Normalization
TODO DOCUMENTATION

### Floating windows
TODO DOCUMENTATION

Normally, floating windows are not part of the tiling tree except for the 'focus' command. From 'focus' command perspective,
floating windows are part of the tree.

## Default keybindings
TODO DOCUMENTATION the idea behind default keybindings

## Configuring AeroSpace

AeroSpace will read config file from `~/.aerospace.toml`. Please see the following config samples:
- The default config contains all possible keys with comments: [default-config.toml](../config-examples/default-config.toml)
- i3 like config: [i3-like-config-example.toml](../config-examples/i3-like-config-example.toml)

AeroSpace uses TOML format for the config. TOML is a popular format with open specification. TOML is easy to read, and it supports
comments. See [TOML site for more info](https://toml.io/en/)

### Binding modes
TODO DOCUMENTATION

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
TODO DOCUMENTATION

## Multiple displays
TODO DOCUMENTATION
TODO DOCUMENTATION. Add difference with i3

