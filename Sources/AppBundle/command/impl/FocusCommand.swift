import AppKit
import Common

private let focusCoordinator = FocusCoordinator()

private actor FocusCoordinator {
    private var isLocked = false
    private var waiters: [CheckedContinuation<(), Never>] = []

    func run<T: Sendable>(_ body: @MainActor () async throws -> T) async throws -> T {
        await lock()
        do {
            let result = try await body()
            unlock()
            return result
        } catch {
            unlock()
            throw error
        }
    }

    private func lock() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func unlock() {
        if waiters.isEmpty {
            isLocked = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

struct FocusCommand: Command {
    let args: FocusCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        if let window = target.windowOrNil, await shouldFailBecauseFullscreen_nonCancellable(
            window: window,
            failIfFullscreen: args.failIfFullscreen,
            failIfMacosNativeFullscreen: args.failIfMacosNativeFullscreen,
        ) {
            return .fail
        }
        switch args.target {
            case .direction(let direction):
                return (try? await focusCoordinator.run { @MainActor in
                    let snapshot = try await FocusSnapshot.capture(target: target, includeFloating: args.floatingAsTiling)
                    if let windowToFocus = snapshot.resolveDirectional(direction) {
                        return snapshot.focusIfStillCurrent(windowToFocus)
                    } else {
                        return hitWorkspaceBoundaries(
                            target,
                            io,
                            args,
                            direction,
                            workspaceWrapWindow: snapshot.resolveWorkspaceWrap(direction: direction),
                        )
                    }
                }) ?? .fail
            case .windowId(let windowId):
                if let windowToFocus = Window.get(byId: windowId) {
                    return .from(bool: windowToFocus.focusWindow())
                } else {
                    return .fail(io.err("Can't find window with ID \(windowId)"))
                }
            case .dfsIndex(let dfsIndex):
                guard let snapshot = try? await FocusSnapshot.capture(target: target, includeFloating: args.floatingAsTiling) else { return .fail }
                let windows = snapshot.dfsWindows()
                if let windowToFocus = windows.getOrNil(atIndex: Int(dfsIndex)) {
                    return snapshot.focusIfStillCurrent(windowToFocus)
                } else {
                    return .fail(io.err("Can't find window with DFS index \(dfsIndex)"))
                }
            case .dfsRelative(let nextPrev):
                guard let snapshot = try? await FocusSnapshot.capture(target: target, includeFloating: args.floatingAsTiling) else { return .fail }
                let windows = snapshot.dfsWindows()
                guard let currentIndex = windows.firstIndex(where: { $0 == target.windowOrNil }) else {
                    return .fail
                }
                var targetIndex = switch nextPrev {
                    case .dfsNext: currentIndex + 1
                    case .dfsPrev: currentIndex - 1
                }
                if !(0 ..< windows.count).contains(targetIndex) {
                    switch args.boundariesAction {
                        case .stop: return .succ
                        case .fail: return .fail
                        case .wrapAroundTheWorkspace: targetIndex = (targetIndex + windows.count) % windows.count
                        case .wrapAroundAllMonitors: return .fail(io.err(bugPrompt("Must be discarded by args parser")))
                    }
                }
                return snapshot.focusIfStillCurrent(windows[targetIndex])
        }
    }
}

@MainActor private func hitWorkspaceBoundaries(
    _ target: LiveFocus,
    _ io: CmdIo,
    _ args: FocusCmdArgs,
    _ direction: CardinalDirection,
    workspaceWrapWindow: Window? = nil,
) -> BinaryExitCode {
    switch args.boundaries {
        case .workspace:
            return switch args.boundariesAction {
                case .stop: .succ
                case .fail: .fail
                case .wrapAroundTheWorkspace: wrapAroundTheWorkspace(target, io, direction, workspaceWrapWindow: workspaceWrapWindow)
                case .wrapAroundAllMonitors: .fail(io.err("Must be discarded by args parser"))
            }
        case .allMonitorsOuterFrame:
            let currentMonitor = target.workspace.workspaceMonitorInfo
            guard let (monitors, index) = currentMonitor.findRelativeMonitor(inDirection: direction) else {
                return .fail(io.err(bugPrompt("Should never happen. Can't find the current monitor")))
            }

            if let targetMonitor = monitors.getOrNil(atIndex: index) {
                return .from(bool: targetMonitor.visibleWorkspace.focusWorkspace())
            } else {
                guard let wrapped = monitors.get(wrappingIndex: index) else { return .fail(io.err(bugPrompt("\(index) \(monitors)"))) }
                return hitAllMonitorsOuterFrameBoundaries(target, io, args, direction, wrapped, workspaceWrapWindow: workspaceWrapWindow)
            }
    }
}

@MainActor private func hitAllMonitorsOuterFrameBoundaries(
    _ target: LiveFocus,
    _ io: CmdIo,
    _ args: FocusCmdArgs,
    _ direction: CardinalDirection,
    _ wrappedMonitor: MonitorInfo,
    workspaceWrapWindow: Window? = nil,
) -> BinaryExitCode {
    switch args.boundariesAction {
        case .stop:
            return .succ
        case .fail:
            return .fail
        case .wrapAroundTheWorkspace:
            return wrapAroundTheWorkspace(target, io, direction, workspaceWrapWindow: workspaceWrapWindow)
        case .wrapAroundAllMonitors:
            wrappedMonitor.visibleWorkspace.findLeafWindowRecursive(snappedTo: direction.opposite)?.markAsMostRecentChild()
            return .from(bool: wrappedMonitor.visibleWorkspace.focusWorkspace())
    }
}

@MainActor private func wrapAroundTheWorkspace(
    _ target: LiveFocus,
    _ io: CmdIo,
    _ direction: CardinalDirection,
    workspaceWrapWindow: Window? = nil,
) -> BinaryExitCode {
    guard let windowToFocus = workspaceWrapWindow ?? target.workspace.findLeafWindowRecursive(snappedTo: direction.opposite) else {
        return .fail(io.err(noWindowIsFocused))
    }
    return .from(bool: windowToFocus.focusWindow())
}

extension TreeNode {
    @MainActor
    func findLeafWindowRecursive(snappedTo direction: CardinalDirection) -> Window? {
        switch nodeCases {
            case .workspace(let workspace):
                return workspace.rootTilingContainer.findLeafWindowRecursive(snappedTo: direction)
            case .window(let window):
                return window
            case .tilingContainer(let container):
                if direction.orientation == container.orientation {
                    return (direction.isPositive ? container.children.last : container.children.first)?
                        .findLeafWindowRecursive(snappedTo: direction)
                } else {
                    return mostRecentChild?.findLeafWindowRecursive(snappedTo: direction)
                }
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer,
                 .floatingWindowsContainer:
                die("Impossible")
        }
    }
}

extension TreeNode {
    @MainActor func findInhabitedLeafWindowRecursive(snappedTo direction: CardinalDirection) -> Window? {
        switch nodeCases {
            case .workspace(let workspace):
                return workspace.rootTilingContainer.findInhabitedLeafWindowRecursive(snappedTo: direction)
            case .window(let window):
                return window.lifeStatus.isInhabited ? window : nil
            case .tilingContainer(let container):
                if direction.orientation == container.orientation {
                    return (direction.isPositive ? container.inhabitedChildren.last : container.inhabitedChildren.first)?
                        .findInhabitedLeafWindowRecursive(snappedTo: direction)
                } else {
                    return container.mostRecentInhabitedChild?.findInhabitedLeafWindowRecursive(snappedTo: direction)
                }
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer,
                 .monitor, .workspacesContainer,
                 .floatingWindowsContainer:
                die("Impossible")
        }
    }
}
