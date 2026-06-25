import AppKit
import Common

struct LayoutCommand: Command {
    let args: LayoutCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }

        let node: ConventionalWindowParentCases
        switch args.root ? nil : target.windowOrNil {
            case let window?:
                switch window.windowParentCases {
                    case .floatingWindowsContainer(let it):
                        node = .floatingWindowsContainer(it)
                    case .tilingContainer(let it):
                        node = .tilingContainer(it)
                    case .macosFullscreenWindowsContainer,
                         .macosHiddenAppsWindowsContainer,
                         .macosMinimizedWindowsContainer:
                        let msg = "Can't change layout for macOS minimized, fullscreen windows or windows or hidden apps. " +
                            "This behavior is subject to change"
                        return .fail(io.err(msg))
                    case .unbound, .macosPopupWindowsContainer:
                        return .fail(io.err(bugPrompt()))
                }
            case nil:
                node = .tilingContainer(target.workspace.rootTilingContainer)
        }

        let targetDescription = args.toggleBetween.val.first(where: { !node.matchesDescription($0) })
            ?? args.toggleBetween.val.first.orDie()
        if node.matchesDescription(targetDescription) {
            switch args.failIfNoop {
                case true: return .fail
                case false:
                    let msg = "Already in the requested \(targetDescription.rawValue) mode. " +
                        "Tip: use --fail-if-noop to exit with non-zero exit code"
                    return .succ(io.err(msg))
            }
        }
        switch targetDescription {
            case .h_accordion:
                return changeTilingLayout(io, targetLayout: .accordion, targetOrientation: .h, node: node)
            case .v_accordion:
                return changeTilingLayout(io, targetLayout: .accordion, targetOrientation: .v, node: node)
            case .h_tiles:
                return changeTilingLayout(io, targetLayout: .tiles, targetOrientation: .h, node: node)
            case .v_tiles:
                return changeTilingLayout(io, targetLayout: .tiles, targetOrientation: .v, node: node)
            case .accordion:
                return changeTilingLayout(io, targetLayout: .accordion, targetOrientation: nil, node: node)
            case .tiles:
                return changeTilingLayout(io, targetLayout: .tiles, targetOrientation: nil, node: node)
            case .horizontal:
                return changeTilingLayout(io, targetLayout: nil, targetOrientation: .h, node: node)
            case .vertical:
                return changeTilingLayout(io, targetLayout: nil, targetOrientation: .v, node: node)
            case .tiling:
                guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
                switch node {
                    case .tilingContainer:
                        return .succ // Nothing to do
                    case .floatingWindowsContainer(let container):
                        window.lastFloatingSize = (try? await window.getAxSize(.nonCancellable)) ?? window.lastFloatingSize
                        guard let workspace = container.nodeWorkspace else { return .fail(io.err(bugPrompt())) }
                        do {
                            try await window.relayoutWindow(on: workspace, .nonCancellable, forceTile: true)
                        } catch {
                            return .fail(io.err(bugPrompt()))
                        }
                        return .succ
                }
            case .floating:
                guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
                let workspace = target.workspace
                window.bindAsFloatingWindow(to: workspace)
                if let size = window.lastFloatingSize { window.setAxFrame(nil, size) }
                return .succ
        }
    }
}

@MainActor private func changeTilingLayout(
    _ io: CmdIo,
    targetLayout: Layout?,
    targetOrientation: Orientation?,
    node: ConventionalWindowParentCases,
) -> BinaryExitCode {
    switch node {
        case .floatingWindowsContainer:
            return .fail(io.err("The window is non-tiling"))
        case .tilingContainer(let parent):
            let targetOrientation = targetOrientation ?? parent.orientation
            let targetLayout = targetLayout ?? parent.layout
            parent.layout = targetLayout
            parent.changeOrientation(targetOrientation)
            return .succ
    }
}

extension ConventionalWindowParentCases {
    fileprivate func matchesDescription(_ layout: LayoutCmdArgs.LayoutDescription) -> Bool {
        return switch layout {
            case .accordion:   tilingContainerOrNil?.layout == .accordion
            case .tiles:       tilingContainerOrNil?.layout == .tiles
            case .horizontal:  tilingContainerOrNil?.orientation == .h
            case .vertical:    tilingContainerOrNil?.orientation == .v
            case .h_accordion: tilingContainerOrNil.map { $0.layout == .accordion && $0.orientation == .h } == true
            case .v_accordion: tilingContainerOrNil.map { $0.layout == .accordion && $0.orientation == .v } == true
            case .h_tiles:     tilingContainerOrNil.map { $0.layout == .tiles && $0.orientation == .h } == true
            case .v_tiles:     tilingContainerOrNil.map { $0.layout == .tiles && $0.orientation == .v } == true
            case .tiling:      tilingContainerOrNil != nil
            case .floating:    floatingWindowsContainerOrNil != nil
        }
    }
}
