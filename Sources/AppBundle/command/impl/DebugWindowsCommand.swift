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
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        if args.windowId != nil && args.appBundleId != nil {
            return .fail(io.err("--window-id is incompatible with --app-bundle-id"))
        }
        if let appBundleId = args.appBundleId {
            return await dumpAppWindowsDebugInfo(appBundleId, io)
        }
        if let windowId = args.windowId {
            guard let window = Window.get(byId: windowId) else {
                return .fail(io.err("Can't find window with the specified window-id: \(windowId)"))
            }
            guard let a = try? await dumpWindowDebugInfo(window, .nonCancellable) else { return .fail(io.err(bugPrompt())) }
            io.out(a + "\n")
            io.out(disclaimer)
            return .succ
        }
        switch debugWindowsState {
            case .recording:
                debugWindowsState = .notRecording
                io.out(debugWindowsLog.values.joined(separator: "\n\n"))
                io.out("\n" + disclaimer + "\n")
                io.out("Debug session finished" + "\n")
                debugWindowsLog = [:]
                return .succ
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
                guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
                if let window = target.windowOrNil {
                    do {
                        try await debugWindowsIfRecording(window, .nonCancellable)
                    } catch {
                        return .fail(io.err(bugPrompt(String(describing: error))))
                    }
                }
                return .succ
            case .recordingAborted:
                io.out(
                    """
                    Recording of the previous session was aborted after \(debugWindowsLimit) windows has been focused
                    Run the command one more time to start new debug session
                    """,
                )
                debugWindowsState = .notRecording
                debugWindowsLog = [:]
                return .fail
        }
    }
}

@MainActor
private func dumpWindowDebugInfo(_ window: Window, _ cm: CancellationMode) async throws -> String {
    let window = window as! MacWindow
    var result: [String: Json] = try await window.dumpAxInfo(cm)

    let windowLevel = getWindowLevel(for: window.windowId)
    result["Aero.windowLevel"] = windowLevel?.toJson() ?? .null
    result["Aero.axWindowId"] = .int(window.windowId)
    result = result + (try await dumpAppDebugInfo(window.macApp, cm))
    result = result + (await dumpTreeNodeDebugInfo(window))

    let isDialog = try await window.isDialogHeuristic(windowLevel, cm)
    let isWindow = try await window.isWindowHeuristic(windowLevel, cm)
    result["Aero.AxUiElementWindowType"] = .string(AxUiElementWindowType.new(isWindow: isWindow, isDialog: { isDialog }).rawValue)
    result["Aero.AxUiElementWindowType_isDialogHeuristic"] = .bool(isDialog)

    return JSONEncoder.aeroSpaceDefault.encodeToString(result).prettyDescription
        .prefixLines(with: "\(window.app.rawAppBundleId ?? "nil-bundle-id").\(window.windowId) ||| ")
}

@MainActor
private func dumpAppDebugInfo(_ macApp: MacApp, _ cm: CancellationMode) async throws -> [String: Json] {
    let appInfoDic = macApp.nsApp.bundleURL.flatMap { Bundle.init(url: $0) }?.infoDictionary ?? [:]
    var result: [String: Json] = [:]
    result["Aero.macOS.version"] = .string(ProcessInfo().operatingSystemVersionString) // because built-in apps might behave differently depending on the OS version
    result["Aero.App.appBundleId"] = .stringOrNull(macApp.rawAppBundleId)
    result["Aero.App.pid"] = .int(Int(macApp.pid))
    result["Aero.App.versionShort"] = .stringOrNull(appInfoDic["CFBundleShortVersionString"] as? String)
    result["Aero.App.version"] = .stringOrNull(appInfoDic["CFBundleVersion"] as? String)
    result["Aero.App.nsApp.activationPolicy"] = .string(macApp.nsApp.activationPolicy.prettyDescription)
    result["Aero.App.nsApp.execPath"] = .stringOrNull(macApp.nsApp.executableURL?.description)
    result["Aero.App.nsApp.appBundlePath"] = .stringOrNull(macApp.nsApp.bundleURL?.description)
    result["Aero.AXApp"] = .dict(try await macApp.dumpAppAxInfo(cm))
    return result
}

@MainActor
private func dumpTreeNodeDebugInfo(_ window: MacWindow) async -> [String: Json] {
    var result: [String: Json] = [:]
    result["Aero.workspace"] = .stringOrNull(window.nodeWorkspace?.name)
    result["Aero.treeNodeParent"] = .string(String(describing: window.parent))
    var matchingCallbacks: [Json] = []
    for callback in config.onWindowDetected where await callback.matches(window) {
        matchingCallbacks.append(callback.debugJson)
    }
    result["Aero.on-window-detected"] = .array(matchingCallbacks)
    return result
}

@MainActor
private func dumpAppWindowsDebugInfo(_ appBundleId: String, _ io: CmdIo) async -> BinaryExitCode {
    let apps = MacApp.allAppsMap.values.filter { $0.rawAppBundleId == appBundleId }
    if apps.isEmpty {
        let running = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == appBundleId }
        return if running.isEmpty {
            .fail(io.err("No running application with app-bundle-id '\(appBundleId)'"))
        } else {
            .fail(io.err(running.map {
                "Application '\(appBundleId)' (pid=\($0.processIdentifier), activationPolicy=\($0.activationPolicy.prettyDescription)) is running, but it's not registered in AeroSpace"
            }.joined(separator: "\n")))
        }
    }
    var entries: [String] = []
    for app in apps {
        let windowLevels = getAllWindowLevels()
        guard let appDump = try? await dumpAppDebugInfo(app, .nonCancellable),
              let dumps = try? await app.dumpAllWindowsAxInfo(windowLevels, .nonCancellable)
        else { return .fail(io.err(bugPrompt())) }
        for (index, idAndDump) in dumps.enumerated() {
            let (windowId, dump) = idAndDump
            var result = dump + appDump
            if let windowId {
                result["Aero.axWindowId"] = .int(windowId)
                result["Aero.windowLevel"] = windowLevels[windowId]?.toJson() ?? .null
            } else {
                result["Aero.axWindowId"] = .null
                result["Aero.windowLevel"] = .null
            }
            if let windowId, let macWindow = MacWindow.allWindowsMap[windowId] {
                result["Aero.debug.registered"] = .bool(true)
                result = result + (await dumpTreeNodeDebugInfo(macWindow))
            } else {
                result["Aero.debug.registered"] = .bool(false)
            }
            let prefix = "\(appBundleId).\(windowId?.description ?? "nil-window-id-\(index)") ||| "
            entries.append(JSONEncoder.aeroSpaceDefault.encodeToString(result).prettyDescription.prefixLines(with: prefix))
        }
    }
    io.out(entries.joined(separator: "\n\n") + "\n")
    io.out(disclaimer)
    return .succ
}

@MainActor
func debugWindowsIfRecording(_ window: Window, _ cm: CancellationMode) async throws {
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
    debugWindowsLog[window.windowId] = try await dumpWindowDebugInfo(window, cm)
}
