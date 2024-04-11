import Common

extension Workspace {
    var rootTilingContainer: TilingContainer {
        let containers = children.filterIsInstance(of: TilingContainer.self)
        switch containers.count {
            case 0:
                let orientation: Orientation = switch config.defaultRootContainerOrientation {
                    case .horizontal: .h
                    case .vertical: .v
                    case .auto: workspaceMonitor.lets { $0.width >= $0.height } ? .h : .v
                }
                return TilingContainer(parent: self, adaptiveWeight: 1, orientation, config.defaultRootContainerLayout, index: INDEX_BIND_LAST)
            case 1:
                return containers.singleOrNil()!
            default:
                error("Workspace must contain zero or one tiling container as its child")
        }
    }

    static var focused: Workspace { // todo drop?
        //check(focusSourceOfTruth == .ownModel)
        return Workspace.get(byName: focusedWorkspaceName)
            //: (nativeFocusedWindow?.workspace ?? Workspace.get(byName: focusedWorkspaceName))
    }

    var floatingWindows: [Window] {
        children.filterIsInstance(of: Window.self)
    }

    var macOsNativeFullscreenWindowsContainer: MacosFullscreenWindowsContainer {
        let containers = children.filterIsInstance(of: MacosFullscreenWindowsContainer.self)
        return switch containers.count {
            case 0: MacosFullscreenWindowsContainer(parent: self)
            case 1: containers.singleOrNil()!
            default: errorT("Workspace must contain zero or one MacosFullscreenWindowsContainer")
        }
    }

    var forceAssignedMonitor: Monitor? {
        guard let monitorDescriptions = config.workspaceToMonitorForceAssignment[name] else { return nil }
        let sortedMonitors = sortedMonitors
        return monitorDescriptions.lazy
            .compactMap { $0.resolveMonitor(sortedMonitors: sortedMonitors) }
            .first
    }
}
