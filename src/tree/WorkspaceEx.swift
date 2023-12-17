import Common

extension Workspace {
    var rootTilingContainer: TilingContainer {
        let containers = children.filterIsInstance(of: TilingContainer.self)
        switch containers.count {
        case 0:
            let orientation: Orientation
            switch config.defaultRootContainerOrientation {
            case .horizontal:
                orientation = .h
            case .vertical:
                orientation = .v
            case .auto:
                orientation = monitor.lets { $0.width >= $0.height } ? .h : .v
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
        workspace.children.filterIsInstance(of: Window.self)
    }

    var forceAssignedMonitor: Monitor? {
        guard let monitorDescriptions = config.workspaceToMonitorForceAssignment[name] else { return nil }
        let sortedMonitors = sortedMonitors
        return monitorDescriptions.lazy
            .map { desc in
                switch desc {
                case .sequenceNumber(let number):
                    return sortedMonitors.getOrNil(atIndex: number - 1)
                case .main:
                    return mainMonitor
                case .secondary:
                    return sortedMonitors.takeIf { $0.count == 2 }?
                        .first { $0.rect.topLeftCorner != mainMonitor.rect.topLeftCorner }
                case .pattern(let regex):
                    return sortedMonitors.first { monitor in monitor.name.contains(regex) }
                }
            }
            .filterNotNil()
            .first
    }

    func layoutWorkspace() {
        if isEffectivelyEmpty { return }
        let rect = monitor.visibleRectPaddedByOuterGaps
        layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height, virtual: rect)
    }
}
