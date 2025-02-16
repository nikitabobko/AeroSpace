import AppKit
import Common
import OrderedCollections

private let priorityAx: Set<String> = [
    Ax.titleAttr.key,
    Ax.roleAttr.key,
    Ax.subroleAttr.key,
    Ax.identifierAttr.key,
]

private let disclaimer =
    """
    !!! DISCLAIMER !!!
    !!! 'debug-windows' command is not stable API. Please don't rely on the command existence and output format !!!
    !!! The only intended use case is to report bugs about incorrect windows handling !!!
    """

private var debugWindowsState: DebugWindowsState = .notRecording
private var debugWindowsLog: OrderedDictionary<UInt32, String> = [:]
private let debugWindowsLimit = 5

enum DebugWindowsState {
    case recording
    case notRecording
    case recordingAborted
}

struct DebugWindowsCommand: Command {
    let args = DebugWindowsCmdArgs(rawArgs: .init([]))

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        switch debugWindowsState {
            case .recording:
                debugWindowsState = .notRecording
                io.out((debugWindowsLog.values + [disclaimer, "Debug session finished"]).joined(separator: "\n\n"))
                debugWindowsLog = [:]
                return true
            case .notRecording:
                debugWindowsState = .recording
                io.out(
                    """
                    Debug windows session has started
                    1. Focus the problematic window
                    2. Run 'aerospace debug-windows' once again to finish the session and get the results
                    """
                )
                debugWindowsLog = [:]
                // Make sure that the Terminal window that started the recording is recorded first
                guard let target = args.resolveTargetOrReportError(env, io) else { return false }
                if let window = target.windowOrNil {
                    debugWindowsIfRecording(window)
                }
                return true
            case .recordingAborted:
                io.out(
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
        case .recording: break
        case .notRecording, .recordingAborted: return
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
    let appId = app.id ?? "NULL-APP-BUNDLE-ID"
    let windowPrefix = appId + ".window.\(window.windowId)"
    var result: [String] = []

    result.append("\(windowPrefix) windowId: \(window.windowId)")
    result.append("\(windowPrefix) workspace: \(window.nodeWorkspace?.name ?? "nil")")
    result.append("\(windowPrefix) treeNodeParent: \(window.parent)")
    result.append("\(windowPrefix) recognizedAsDialog: \(isDialogHeuristic(window.axWindow, app))")
    result.append(dumpAx(window.axWindow, windowPrefix, .window))

    let appPrefix = appId.padding(toLength: windowPrefix.count, withPad: " ", startingAt: 0)
    result.append(dumpAx(app.axApp, appPrefix, .app))

    debugWindowsLog[window.windowId] = result.joined(separator: "\n")
}

private func prettyValue(_ value: Any?) -> String {
    if value is NSArray, let arr = value as? [Any?] {
        return "[\n" + arr.map(prettyValue).joined(separator: ",\n").prependLines("    ") + "\n]"
    }
    if let value {
        let ax = value as! AXUIElement
        if ax.get(Ax.roleAttr) == kAXButtonRole {
            let dumped = dumpAx(ax, "", .button).prependLines("    ")
            return "AXUIElement {\n" + dumped + "\n}"
        }
        if let windowId = ax.containingWindowId() {
            let title = ax.get(Ax.titleAttr)?.doubleQuoted ?? "nil"
            let role = ax.get(Ax.roleAttr)?.doubleQuoted ?? "nil"
            let subrole = ax.get(Ax.subroleAttr)?.doubleQuoted ?? "nil"
            return "AXUIElement(windowId=\(windowId), title=\(title), role=\(role), subrole=\(subrole))"
        }
    }
    let str = String(describing: value)
    return str.contains("\n")
        ? "\n" + str.prependLines("    ")
        : str
}

private func dumpAx(_ ax: AXUIElement, _ prefix: String, _ kind: AxKind) -> String {
    var result: [String] = []
    var ignored: [String] = []
    for key: String in ax.attrs.sortedBy({ priorityAx.contains($0) ? 0 : 1 }) {
        var raw: AnyObject?
        AXUIElementCopyAttributeValue(ax, key as CFString, &raw)
        if globalIgnore.contains(key) || kindSpecificIgnore[kind]?.contains(key) == true {
            ignored.append(key)
        } else {
            result.append("\(key): \(prettyValue(raw as Any?))".prependLines("\(prefix) "))
        }
    }
    if !ignored.isEmpty {
        result.append("\(prefix) Ignored: \(ignored.joined(separator: ", "))")
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

private enum AxKind: Hashable {
    case button
    case window
    case app
}

private let globalIgnore: Set<String> = [
    kAXRoleDescriptionAttribute, // localized
    "AXChildren", // too verbose
    "AXChildrenInNavigationOrder", // too verbose
    kAXHelpAttribute, // localized
]

private let kindSpecificIgnore: [AxKind: Set<String>] = [
    .button: [
        kAXPositionAttribute,
        kAXFocusedAttribute,
        "AXFrame",
        kAXSizeAttribute,
        kAXEditedAttribute,
    ],
    .app: [
        kAXHiddenAttribute,
        "AXPreferredLanguage",
        "AXEnhancedUserInterface",
    ],
]
