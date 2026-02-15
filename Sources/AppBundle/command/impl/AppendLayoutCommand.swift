import AppKit
import Common

struct AppendLayoutCommand: Command {
    let args: AppendLayoutCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let jsonString = io.readStdin()
        guard !jsonString.isEmpty else {
            return io.err("append-layout: No JSON layout provided on stdin")
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            return io.err("append-layout: Failed to read stdin as UTF-8")
        }

        let spec: LayoutSpec
        do {
            spec = try JSONDecoder().decode(LayoutSpec.self, from: jsonData)
        } catch {
            return io.err("append-layout: Failed to parse JSON layout: \(error)")
        }

        guard case .container(let rootSpec) = spec else {
            return io.err("append-layout: Root of layout spec must be a container, not a window")
        }

        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let workspace = target.workspace
        let root = workspace.rootTilingContainer

        // Step 1: Flatten — rebind all tiling windows to root
        let windows = root.allLeafWindowsRecursive
        for window in windows {
            window.bind(to: root, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        }
        workspace.normalizeContainers()

        // Step 2: Collect available windows by window ID and bundle ID
        var availableById: [UInt32: Window] = [:]
        var availableByBundleId: [String: [Window]] = [:]
        for window in workspace.rootTilingContainer.allLeafWindowsRecursive {
            availableById[window.windowId] = window
            let bundleId = window.app.rawAppBundleId ?? ""
            availableByBundleId[bundleId, default: []].append(window)
        }

        // Step 3: Unbind all windows from root (they'll be re-bound during tree construction)
        let allWindows = workspace.rootTilingContainer.allLeafWindowsRecursive
        for window in allWindows {
            window.unbindFromParent()
        }

        // Step 4: Set root container layout and orientation from spec
        let rootContainer = workspace.rootTilingContainer
        rootContainer.layout = rootSpec.layout.parseLayout() ?? .tiles
        let targetOrientation: Orientation = rootSpec.orientation == "horizontal" ? .h : .v
        rootContainer.changeOrientation(targetOrientation)

        // Step 5: Build tree recursively from spec children
        for (i, childSpec) in rootSpec.children.enumerated() {
            buildTree(spec: childSpec, parent: rootContainer, availableById: &availableById, availableByBundleId: &availableByBundleId, index: i)
        }

        // Step 6: Re-bind any unmatched windows to root
        for window in availableById.values {
            window.bind(to: workspace.rootTilingContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        }

        // Step 7: Remove only completely empty leaf containers (preserve structure otherwise)
        removeEmptyLeafContainers(workspace.rootTilingContainer)

        return true
    }
}

@MainActor
private func buildTree(spec: LayoutSpec, parent: NonLeafTreeNodeObject, availableById: inout [UInt32: Window], availableByBundleId: inout [String: [Window]], index: Int) {
    switch spec {
        case .container(let containerSpec):
            let orientation: Orientation = containerSpec.orientation == "horizontal" ? .h : .v
            let layout: Layout = containerSpec.layout.parseLayout() ?? .tiles
            let weight: CGFloat = containerSpec.weight ?? 1
            let container = TilingContainer(
                parent: parent,
                adaptiveWeight: weight,
                orientation,
                layout,
                index: index,
            )
            for (i, child) in containerSpec.children.enumerated() {
                buildTree(spec: child, parent: container, availableById: &availableById, availableByBundleId: &availableByBundleId, index: i)
            }
        case .window(let windowSpec):
            let weight: CGFloat = windowSpec.weight ?? 1
            // Fix #3: Try exact window-id match first, then fall back to bundle-id
            if let windowId = windowSpec.windowId, let window = availableById[windowId] {
                consumeWindow(window, availableById: &availableById, availableByBundleId: &availableByBundleId)
                window.bind(to: parent, adaptiveWeight: weight, index: index)
            } else if var windows = availableByBundleId[windowSpec.appBundleId], !windows.isEmpty {
                let window = windows.removeFirst()
                availableByBundleId[windowSpec.appBundleId] = windows
                availableById.removeValue(forKey: window.windowId)
                window.bind(to: parent, adaptiveWeight: weight, index: index)
            }
    }
}

/// Remove a matched window from both lookup dictionaries
@MainActor
private func consumeWindow(_ window: Window, availableById: inout [UInt32: Window], availableByBundleId: inout [String: [Window]]) {
    availableById.removeValue(forKey: window.windowId)
    let bundleId = window.app.rawAppBundleId ?? ""
    if var windows = availableByBundleId[bundleId] {
        windows.removeAll { $0.windowId == window.windowId }
        availableByBundleId[bundleId] = windows.isEmpty ? nil : windows
    }
}

/// Remove leaf containers that have zero children, but preserve the rest of the tree structure
@MainActor
private func removeEmptyLeafContainers(_ container: TilingContainer) {
    // Process children first (bottom-up)
    for child in container.children {
        if case .tilingContainer(let childContainer) = child.nodeCases {
            removeEmptyLeafContainers(childContainer)
        }
    }
    // Remove this container if it's empty and not the root
    if container.children.isEmpty && container.parent is TilingContainer {
        container.unbindFromParent()
    }
}

// MARK: - Layout Spec Model

private enum LayoutSpec: Decodable {
    case container(ContainerSpec)
    case window(WindowSpec)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
            case "container":
                self = .container(try ContainerSpec(from: decoder))
            case "window":
                self = .window(try WindowSpec(from: decoder))
            case "workspace":
                // Unwrap get-tree workspace output: use the "tiling" field
                let ws = try WorkspaceSpec(from: decoder)
                self = .container(ws.tiling)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type: \(type)")
        }
    }
}

private struct ContainerSpec: Decodable {
    let layout: String
    let orientation: String
    let children: [LayoutSpec]
    let weight: CGFloat?
}

private struct WorkspaceSpec: Decodable {
    let tiling: ContainerSpec
}

private struct WindowSpec: Decodable {
    let appBundleId: String
    let windowId: UInt32?
    let weight: CGFloat?

    private enum CodingKeys: String, CodingKey {
        case appBundleId = "app-bundle-id"
        case windowId = "window-id"
        case weight
    }
}
