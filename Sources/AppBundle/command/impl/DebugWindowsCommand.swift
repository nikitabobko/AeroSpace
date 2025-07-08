import AppKit
import Common
import OrderedCollections

private let disclaimer =
    """
    !!! DISCLAIMER !!!
    !!! 'debug-windows' command is not stable API. Please don't rely on the command existence and output format !!!
    !!! The only intended use case is to report bugs about incorrect windows handling !!!
    """

@MainActor private var debugWindowsState: DebugWindowsState = .notRecording
@MainActor private var debugWindowsLog: OrderedDictionary<UInt32, String> = [:]
private let debugWindowsLimit = 10

enum DebugWindowsState {
    case recording
    case notRecording
    case recordingAborted
}

struct DebugWindowsCommand: Command {
    let args: DebugWindowsCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        if let windowId = args.windowId {
            guard let window = Window.get(byId: windowId) else {
                return io.err("Can't find window with the specified window-id: \(windowId)")
            }
            io.out(try await dumpWindowDebugInfo(window) + "\n")
            io.out(disclaimer)
            return true
        }
        switch debugWindowsState {
            case .recording:
                debugWindowsState = .notRecording
                io.out(debugWindowsLog.values.joined(separator: "\n\n"))
                io.out("\n" + disclaimer + "\n")
                io.out("Debug session finished" + "\n")
                debugWindowsLog = [:]
                return true
            case .notRecording:
                debugWindowsState = .recording
                debugWindowsLog = [:]
                io.out(
                    """
                    Debug windows session has started
                    1. Focus the problematic window
                    2. Run 'aerospace debug-windows' once again to finish the session and get the results
                    """,
                )
                // Make sure that the Terminal window that started the recording is recorded first
                guard let target = args.resolveTargetOrReportError(env, io) else { return false }
                if let window = target.windowOrNil {
                    try await debugWindowsIfRecording(window)
                }
                return true
            case .recordingAborted:
                io.out(
                    """
                    Recording of the previous session was aborted after \(debugWindowsLimit) windows has been focused
                    Run the command one more time to start new debug session
                    """,
                )
                debugWindowsState = .notRecording
                debugWindowsLog = [:]
                return false
        }
    }
}

@MainActor
private func dumpWindowDebugInfo(_ window: Window) async throws -> String {
    let window = window as! MacWindow
    let appInfoDic = window.macApp.nsApp.bundleURL.flatMap { Bundle.init(url: $0) }?.infoDictionary ?? [:]

    var result: [String: Json] = try await window.dumpAxInfo()

    result["Aero.axWindowId"] = .newOrDie(window.windowId)
    result["Aero.workspace"] = .string(window.nodeWorkspace?.name ?? "nil")
    result["Aero.treeNodeParent"] = .newOrDie(String(describing: window.parent))
    result["Aero.macOS.version"] = .string(ProcessInfo().operatingSystemVersionString) // because built-in apps might behave differently depending on the OS version
    result["Aero.App.appBundleId"] = .newOrDie(window.app.bundleId)
    result["Aero.App.versionShort"] = .newOrDie(appInfoDic["CFBundleShortVersionString"])
    result["Aero.App.version"] = .newOrDie(appInfoDic["CFBundleVersion"])
    result["Aero.App.nsApp.activationPolicy"] = .string(window.macApp.nsApp.activationPolicy.prettyDescription)
    result["Aero.App.nsApp.execPath"] = .string(window.macApp.nsApp.executableURL.prettyDescription)
    result["Aero.AXApp"] = .dict(try await window.macApp.dumpAppAxInfo())

    let isDialog = try await window.isDialogHeuristic()
    let isWindow = try await window.isWindowHeuristic()
    result["Aero.AxUiElementWindowType"] = .newOrDie(AxUiElementWindowType.new(isWindow: isWindow, isDialog: { isDialog }).rawValue)
    result["Aero.AxUiElementWindowType_isDialogHeuristic"] = .newOrDie(isDialog)

    var matchingCallbacks: [Json] = []
    for callback in config.onWindowDetected where try await callback.matches(window) {
        matchingCallbacks.append(callback.debugJson)
    }
    result["Aero.on-window-detected"] = .array(matchingCallbacks)

    return JSONEncoder.aeroSpaceDefault.encodeToString(result).prettyDescription
        .prefixLines(with: "\(window.app.bundleId ?? "nil-bundle-id").\(window.windowId) ||| ")
}

@MainActor
func debugWindowsIfRecording(_ window: Window) async throws {
    switch debugWindowsState {
        case .recording: break
        case .notRecording, .recordingAborted: return
    }
    if debugWindowsLog.count > debugWindowsLimit {
        debugWindowsState = .recordingAborted
        debugWindowsLog = [:]
    }
    if debugWindowsLog.keys.contains(window.windowId) {
        return
    }
    debugWindowsLog[window.windowId] = try await dumpWindowDebugInfo(window)
}
