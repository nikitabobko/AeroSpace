# Window from a hidden workspace overrides workspace focus

This is related to [Discussion #1939: “Apps randomly move workspaces and which workspace is show randomly changes”](https://github.com/nikitabobko/AeroSpace/discussions/1939).

I've been dealing with this issue for a while and unfortunately the suggested fix with installing it directly was not working because I have been modifying and compiling AeroSpace for myself for a while.

## Example Problem Scenario

When Google Chrome has separate windows in AeroSpace workspaces `3` and `M`, switching `3 → 1 → 3` can immediately switch back to `M`.

The affected Chrome windows are ordinary top-level windows in the same browser
process, not windows owned by Chrome renderer/helper subprocesses.

This initially looked like Chrome only returning stale focus once. The
Accessibility event trace showed a more specific sequence: Chrome first reports
the requested workspace-`3` window as focused and main, then reports the
workspace-`M` window as focused and main a few milliseconds later. AeroSpace
accepted that second event and reversed its own workspace selection.

The workspace-`M` window can be visible on a different monitor, so visibility
of an AeroSpace workspace is not a reliable way to filter the event.

## Environment

- macOS: `26.6.2 (25G83)`
- Google Chrome: `157.0.8103.79`
- Chrome bundle ID: `com.google.Chrome`
- Chrome browser PID: `47121`
- AeroSpace config version: `2`
- AeroSpace reproduction build before the final fix: `0.0.0-SNAPSHOT`

## Relevant configuration

The configuration uses explicit workspace bindings:

```toml
focus-follows-mouse.enabled = false

[mode.main.binding]
left-alt-3 = 'workspace 3'
left-alt-m = 'workspace M'
```

`3` and `M` are both listed in `persistent-workspaces`. No
`on-window-detected` rule matched either affected Chrome window.

## Window and process data before reproduction

`aerospace list-windows` showed these two Chrome windows:

```text
window-id  native-window-id  workspace  monitor  app            PID
11         16999             3          2        Google Chrome  47121
10         27345             M          3        Google Chrome  47121
```

The relevant process tree was:

```text
PID    PPID   process
47121  1      Google Chrome
47133  47121  Google Chrome Helper --type=gpu-process
47134  47121  Google Chrome Helper --type=utility
6414   47121  Google Chrome Helper --type=renderer
8198   47121  Google Chrome Helper --type=renderer
```

This rules out a separate helper process owning one of the windows: both macOS
windows were owned by Chrome PID `47121`.

## Steps to reproduce

1. Place Chrome window `16999` in workspace `3`.
2. Place Chrome window `27345` in workspace `M`.
3. Focus another app or workspace.
4. Run `aerospace workspace 3`, `aerospace workspace 1`, then
   `aerospace workspace 3`; or invoke the equivalent workspace bindings.
5. Wait approximately one second.

## Expected result

Workspace `3` remains focused and Chrome window `16999` is the focused Chrome
window.

## Actual result

Before the final fix, the completed sequence left this window focused:

```text
27345    M    Google Chrome
```

`aerospace debug-windows --window-id 16999` showed Chrome was frontmost but
exposed window `27345` as focused and main:

```text
AXFocusedWindow = AXUIElement(windowId_native=27345)
AXMainWindow    = AXUIElement(windowId_native=27345)
AXFrontmost     = 1

# Target window 16999
AXFocused       = 0
AXMain          = 1
Aero.workspace  = 3
```

An Accessibility observer captured the focus reversal directly:

```text
0.571s  AXFocusedWindowChanged → 16999 (workspace 3)
0.573s  AXMainWindowChanged    → 16999
0.595s  AXFocusedWindowChanged → 27345 (workspace M)
0.607s  AXMainWindowChanged    → 27345
```

Chrome therefore acknowledges the requested window, then reverses to the other
Chrome window about 22 ms later.

## Diagnosis

`getNativeFocusedWindow` reads the frontmost app's `AXFocusedWindow`.
`updateFocusCache` imports that window into AeroSpace focus state.

The original attempted fix recorded the requested native window but cleared
that record as soon as Chrome acknowledged `16999`. Chrome's delayed
`27345` event then arrived after the acknowledgement and was accepted as a new
native focus change.

The final fix uses a bounded, latest-wins native-focus transaction:

1. Each explicit workspace focus request replaces any older pending request.
2. Conflicting native focus events are ignored during a 250 ms settling window.
3. If Chrome reverses focus after acknowledging the target, AeroSpace
   reasserts the final target once after 100 ms.
4. AeroSpace reissues native focus if the native focused window differs from
   its logical target, even when the logical workspace did not change.

This does not block rapid workspace switching. Each new workspace command
cancels the prior transaction, so only the final requested workspace can run
the delayed reassertion.

## Validation

The final debug-build trace showed:

```text
0.380s  Chrome reverted to 27345 (workspace M)
0.516s  AeroSpace reasserted 16999 (workspace 3)
1.534s  Chrome still reported 16999 as focused and main
```

Automated validation passed:

```text
swift test --filter FocusCacheTest
swift test --filter WorkspaceCommandTest
```

The final fix is commit `93925318 Fix Chrome focus reversal after workspace
switch`, pushed to `TreasureJim:fix/chrome-stale-focus`.
