import AppKit

@MainActor private var focusFollowsMouseMonitor: Any? = nil

@MainActor private var task: Task<(), any Error>? = nil

@MainActor func syncFocusFollowsMouse(_ config: Config) {
    if config.focusFollowsMouse.enabled == (focusFollowsMouseMonitor != nil) {
        return
    }

    if !config.focusFollowsMouse.enabled {
        NSEvent.removeMonitor(focusFollowsMouseMonitor.orDie())
        focusFollowsMouseMonitor = nil
        task = nil
        return
    }

    focusFollowsMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { event in
        task?.cancel()
        task = Task.startUnstructured { @MainActor in
            var returned = false // todo debug
            defer {
                if returned {
                    print("return")
                } else {
                    print("canceled")
                }
            }
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try checkCancellation()
            let location = event.locationInWindow.withYAxisFlipped
            print(location)
            let workspace = location.monitorApproximation.activeWorkspace
            print(workspace.name)
            for window in workspace.floatingWindowsContainer.mruChildren {
                try checkCancellation()
                guard let window = window as? Window else { continue }
                guard let rect = try await window.getAxRect(.cancellable) else { continue }
                if rect.contains(location) {
                    try await runLightSession(.focusFollowsMouse, token) {
                        _ = window.focusWindow()
                        window.nativeFocus()
                    }
                    returned = true
                    return
                }
            }
            if let window = location.findIn(tree: workspace.rootTilingContainer, virtual: false) {
                try await runLightSession(.focusFollowsMouse, token) {
                    _ = window.focusWindow()
                    window.nativeFocus()
                }
            }
            returned = true
        }
    }
}
