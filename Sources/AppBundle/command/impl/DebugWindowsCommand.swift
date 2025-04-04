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
private let debugWindowsLimit = 5

enum DebugWindowsState {
    case recording
    case notRecording
    case recordingAborted
}

struct DebugWindowsCommand: Command {
    let args: DebugWindowsCmdArgs

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
                io.out(debugWindowsLog.values.joined(separator: "\n\n") + "\n")
                io.out(disclaimer + "\n")
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
                    """
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
                    """
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
    let appId = window.app.bundleId ?? "NULL-APP-BUNDLE-ID"
    let windowPrefix = appId + ".window.\(window.windowId)"
    var result: [String] = []

    result.append("\(windowPrefix) windowId: \(window.windowId)")
    result.append("\(windowPrefix) workspace: \(window.nodeWorkspace?.name ?? "nil")")
    result.append("\(windowPrefix) treeNodeParent: \(window.parent)")
    result.append("\(windowPrefix) isWindow: \(try await window.isWindowHeuristic())")
    result.append("\(windowPrefix) isDialogHeuristic: \(try await window.isDialogHeuristic())")
    result.append(try await window.dumpAxInfo(windowPrefix))

    let appPrefix = appId.padding(toLength: windowPrefix.count, withPad: " ", startingAt: 0)
    result.append(try await window.macApp.dumpAppAxInfo(appPrefix))

    return result.joined(separator: "\n")
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
