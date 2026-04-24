import AppKit
import AutoRaiseCore
import Common

// Swift end of the AutoRaiseCore raise-routing seam (design.md §D5).
//
// AutoRaise.mm decides *when* and *which* window to raise (its AX walk,
// WINDOW_CORRECTION heuristics, raiseGeneration retry schedule). This router
// decides *how* the focus change lands: resolve the CGWindowID to an
// AeroSpace Window, enforce the current-workspace-only rule (§D7), then run
// the change through setFocus(to:) so the tree model / active-workspace
// state / on-focus-changed callbacks stay consistent.
enum RaiseRouter {
    @MainActor
    static func route(windowId: CGWindowID) {
        // Belt-and-braces for the @convention(c) → MainActor.assumeIsolated hop
        // below: if AutoRaiseCore ever routes a raise off the main thread, we'd
        // rather crash here than silently violate the actor contract.
        assert(Thread.isMainThread)
        guard let window = Window.get(byId: UInt32(windowId)) else { return }
        // Drop raises targeting a window on a non-focused workspace.
        // Matches i3 behavior; also avoids workspace flips when the cursor
        // enters screen regions owned by a non-active workspace.
        guard let targetWorkspace = window.visualWorkspace,
              targetWorkspace == focus.workspace else { return }
        // focusWindow() syncs AeroSpace's internal model; nativeFocus() does the
        // macOS-side AX raise + app activate. Normal commands get the native
        // sync via the refresh session that follows runCmdSeq, but AutoRaise's
        // raise path doesn't go through a command — so we pair them explicitly,
        // matching the pattern in GlobalObserver.
        _ = window.focusWindow()
        window.nativeFocus()
    }

    // C function pointer handed to autoraise_set_route_callback. Must be
    // non-capturing (@convention(c)). Invoked on the main thread because the
    // CGEventTap and dispatch_after retry blocks are both pinned to the main
    // run loop (see AutoRaiseBridge.mm autoraise_start — design.md §D3.c).
    static let cCallback: AutoRaiseRouteRaise = { (windowId: UInt32) in
        MainActor.assumeIsolated {
            route(windowId: CGWindowID(windowId))
        }
    }
}
