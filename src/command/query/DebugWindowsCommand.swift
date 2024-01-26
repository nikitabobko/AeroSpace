import Common

private let priorityAx: Set<String> = [
    Ax.titleAttr.key,
    Ax.roleAttr.key,
    Ax.subroleAttr.key,
    Ax.identifierAttr.key,
]

private let foldAxKeys: Set<String> = ["AXChildrenInNavigationOrder", "AXChildren"]

private let disclaimer =
    """
    !!! DISCLAIMER !!!
    !!! 'debug-windows' command is not stable API. Please don't rely on the command existence and output format !!!
    !!! The only intended use case is to report bugs about incorrect windows handling !!!
    """

private var debugWindowsState: DebugWindowsState = .notRecording
private var debugWindowsLog: [UInt32: String] = [:]
private let debugWindowsLimit = 5

enum DebugWindowsState {
    case recording
    case notRecording
    case recordingAborted
}

struct DebugWindowsCommand: Command {
    let args = DebugWindowsCmdArgs()

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        switch debugWindowsState {
        case .recording:
            debugWindowsState = .notRecording
            state.stdout.append((debugWindowsLog.values + ["Debug session finished"]).joined(separator: "\n\n"))
            debugWindowsLog = [:]
            return true
        case .notRecording:
            debugWindowsState = .recording
            state.stdout.append(
                """
                Debug windows session has started
                1. Focus the problematic window
                2. Run 'aerospace debug-windows' once again to finish the session and get the results

                \(disclaimer)
                """
            )
            debugWindowsLog = [:]
            return true
        case .recordingAborted:
            state.stdout.append(
                """
                Recording of the previous session was aborted after \(debugWindowsLimit) windows has been focused
                Run the command one more time to start new debug session
                """
            )
            debugWindowsState = .notRecording
            debugWindowsLog = [:]
            return false
        }
    }
}

func debugWindowsIfRecording(_ window: Window) {
    switch debugWindowsState {
    case .recording:
        break
    case .notRecording, .recordingAborted:
        return
    }
    if debugWindowsLog.count > debugWindowsLimit {
        debugWindowsState = .recordingAborted
        debugWindowsLog = [:]
    }
    let window = window as! MacWindow
    if debugWindowsLog.keys.contains(window.windowId) {
        return
    }
    let app = window.app as! MacApp
    let appId = app.id ?? "null-app-id"
    let windowPrefix = appId + ".window.\(window.windowId)"
    var result: [String] = []

    result.append("\(windowPrefix) recognizedAsDialog: \(shouldFloat(window.axWindow, app))")
    result.append("\(windowPrefix) AXUIElement: \(window.axWindow)")
    result.append("\(windowPrefix) windowId: \(window.windowId)")
    result.append("\(windowPrefix) workspace: \(window.workspace.name)")
    result.append(dumpAx(window.axWindow, windowPrefix))

    let appPrefix = appId.padding(toLength: windowPrefix.count, withPad: " ", startingAt: 0)
    result.append("\(appPrefix) AXUIElement: \(app.axApp)")
    result.append(dumpAx(app.axApp, appPrefix))

    debugWindowsLog[window.windowId] = result.joined(separator: "\n")
}

private func prettyKeyValue(_ key: String, _ value: Any) -> String {
    let value = String(describing: value)
    return value.contains("\n")
        ? "\(key):\n" + value.prependLines("    ")
        : "\(key): '\(value)'"
}

private func dumpAx(_ ax: AXUIElement, _ prefix: String) -> String {
    var result: [String] = []
    for attr in ax.attrs.sortedBy({ priorityAx.contains($0) ? 0 : 1 }) {
        var raw: AnyObject?
        AXUIElementCopyAttributeValue(ax, attr as CFString, &raw)
        if foldAxKeys.contains(attr) {
            let nillability = raw != nil ? "not-nil" : "nil"
            result.append("\(prefix) \(attr): \(nillability)")
        } else {
            result.append(prettyKeyValue(attr, raw as Any).prependLines("\(prefix) "))
        }
    }
    return result.joined(separator: "\n")
}

extension AXUIElement {
    var attrs: [String] {
        var rawArray: CFArray?
        AXUIElementCopyAttributeNames(self, &rawArray)
        return rawArray as? [String] ?? []
    }
}
