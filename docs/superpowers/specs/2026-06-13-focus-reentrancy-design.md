# Focus Reentrancy Design

Date: 2026-06-13
Branch: codex/focus-session-reentrancy

## Summary

Directional focus currently includes floating windows by temporarily reparenting
them into the real tiling tree. That virtual operation mutates real tree state
after asynchronous AX reads. When multiple focus hotkeys are pressed while AX is
slow, two sessions can interleave and one session can try to unbind a window
that another session has already moved. The observed crash is a symptom of that
boundary violation.

The durable fix is to stop using the real tree as scratch space for focus
calculation. Directional focus should build an immutable snapshot of visible
focus candidates, resolve the target through pure synchronous logic, then apply
only the final focus side effect if the snapshot is still valid.

## Problem

The crash report pointed at:

- `FocusCommand.run`
- `makeFloatingWindowsSeenAsTiling(workspace:)`
- `TreeNode.unbindFromParent()`

The risky pattern is:

1. Read a list of floating windows from the workspace.
2. Await AX geometry calls such as `getCenter()`.
3. Mutate the real tree by unbinding and rebinding windows.
4. Restore the tree in `defer`.

Swift `MainActor` tasks can be re-entered while awaiting AX. During that gap, a
second hotkey session can start from overlapping state and mutate the same
window. The fatal error in `unbindFromParent()` is intentional: it protects the
tree invariant that a node has exactly one valid parent while bound.

## Goals

- Remove focus calculation's dependence on temporary real-tree mutation.
- Preserve existing directional focus behavior as closely as possible.
- Keep focus hotkeys responsive under repeated input and slow AX reads.
- Make stale snapshot application safe when windows, workspaces, or monitors
  change during focus resolution.
- Keep the change narrow enough to review, test, and maintain.

## Non-goals

- Do not redesign the entire refresh session model.
- Do not make sticky a layout type.
- Do not change workspace ownership semantics.
- Do not change general DFS focus behavior unless a test proves it is tied to
  the observed bug.
- Do not add a user-facing config schema for this fix.

## Architecture

### FocusSnapshot

`FocusSnapshot` is created once per directional focus command. It captures the
state needed for target selection:

- focused window id
- focused workspace id/name
- active monitor id
- visible workspace id/name for the monitor
- candidate windows
- a lightweight revision token for validating that the focused context did not
  change before applying the result

Snapshot creation is the only async phase. It may read AX geometry for windows
whose rect is not already available from layout state.

### FocusCandidate

`FocusCandidate` is an immutable value. It contains:

- window id and a weak or validated window reference
- source workspace
- visual workspace
- monitor id
- role: tiling, floating, or sticky
- rect and center
- optional tiling path or ordering metadata

Floating and sticky candidates are represented as candidates, not as temporary
tree nodes.

### FocusResolver

`FocusResolver` is pure synchronous logic:

```swift
resolveDirectional(
    from focusedWindowId: UInt32,
    direction: CardinalDirection,
    snapshot: FocusSnapshot
) -> UInt32?
```

It ranks candidates using the current directional focus geometry rules. It does
not read AX, bind nodes, unbind nodes, mutate workspaces, trigger layout, or
focus windows.

### FocusCoordinator

`FocusCoordinator` serializes directional focus commands only. It prevents a
burst of hotkeys from applying stale results out of order without globally
serializing every refresh session.

The coordinator should be intentionally small:

- enqueue focus command
- build snapshot
- resolve target
- validate snapshot
- apply focus or no-op

It should not become a general app-wide lock.

## Data Flow

1. Hotkey enters `FocusCommand.run`.
2. Command requests a directional focus operation from `FocusCoordinator`.
3. Coordinator builds `FocusSnapshot`.
4. `FocusResolver` chooses a target candidate.
5. Coordinator validates that the focused workspace, monitor, and focused window
   context still match the snapshot.
6. If valid, focus the target window.
7. If invalid, skip the stale result and optionally schedule a light refresh.

## Validation Rules

Before applying a focus result:

- The target window must still exist.
- The target window must still be focusable.
- The source focused window should still be the focused window, unless existing
  behavior explicitly allows focus to move after a concurrent focus change.
- The source monitor and focused workspace context should still match.
- Native minimized, hidden-app, or fullscreen states should remain governed by
  existing macOS/AeroSpace visibility rules.

If validation fails, the command should no-op. It should not try to repair the
tree from stale data.

## Sticky Interaction

Sticky windows should participate in focus as visually visible candidates, but
their real workspace ownership must not change.

This design assumes the sticky model remains:

- `nodeWorkspace`: real owner workspace
- `visualWorkspace`: workspace where the window is currently visible

Focus should use visual workspace membership. Workspace ownership commands
should continue to use node workspace membership.

## Performance

The target steady state is cheaper than the current floating-as-tiling path:

- no temporary tree mutation
- no normalization or layout side effects during focus calculation
- one snapshot per focus command
- one O(n) candidate pass for directional target selection
- layout rects reused for tiling candidates when possible
- AX rect reads limited to candidates that need fresh geometry

The focus-only coordinator avoids the latency cost of a global refresh-session
queue while still making repeated focus hotkeys deterministic.

## Migration Plan

1. Keep the narrow parent-state guard as a temporary safety net while the new
   resolver is built.
2. Add pure model tests for directional candidate ranking.
3. Add focused integration tests that compare old and new behavior for common
   tiling/floating layouts.
4. Switch directional focus to the snapshot resolver.
5. Delete `makeFloatingWindowsSeenAsTiling`.
6. Remove temporary focus crash guards that become unreachable.
7. Re-run the full Swift test suite and local smoke tests.

## Test Plan

Unit tests:

- repeated focus sessions do not double-unbind a floating window
- stale candidate after AX read no-ops instead of crashing
- pure tiling directional focus still matches current behavior
- nested horizontal/vertical containers still match current behavior
- floating window between two tiling windows is selected correctly
- floating window outside the relevant directional cone is ignored
- sticky visible window is a candidate on its visual workspace
- sticky source workspace ownership is unchanged
- multi-monitor focus does not cross monitors unless existing behavior allows it
- workspace switch during snapshot resolution invalidates stale apply

Regression tests:

- `FocusCommand` no longer calls temporary bind/unbind helpers for directional
  focus
- non-sticky, non-floating windows still follow existing hide/focus behavior
- native minimized/fullscreen/hidden-app behavior remains conservative

Manual QA:

- hold the directional focus hotkey while apps are launching
- repeat focus hotkeys with several floating windows on the workspace
- switch workspaces while repeatedly pressing focus
- test with sticky Codex on Desk and Antinote windows
- test on two monitors with sticky/floating windows on only one monitor

## Risks

- The old behavior may contain subtle geometry ranking details that are not
  obvious from code. Golden tests should be added before deleting the old path.
- AX geometry can be stale or slow. Snapshot validation must treat stale data as
  a no-op, not as a reason to mutate tree state.
- Serializing all refresh sessions would be simpler but risks hotkey latency.
  This design intentionally serializes focus only.
- If current tests depend on temporary tree mutation as an implementation detail,
  they should be rewritten around observable focus results.

## Success Criteria

- The reported crash path cannot occur because directional focus no longer
  unbinds floating windows during target calculation.
- Repeated focus hotkeys remain responsive and deterministic.
- Sticky and floating windows can be focused when visually present.
- Workspace switching during a delayed focus command cannot focus a stale target
  on the wrong workspace.
- Full Swift tests pass, `git diff --check` passes, and local smoke testing does
  not reproduce the crash.
