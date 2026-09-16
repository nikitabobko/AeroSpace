import AppKit
import Common

struct ListTreeCommand: Command {
    let args: ListTreeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        let focus = focus
        let workspaces: [Workspace] = args.focused
            ? [focus.workspace]
            : args.workspaces
                .flatMap { filter in
                    switch filter {
                        case .focused: [focus.workspace]
                        case .visible: Workspace.all.filter(\.isVisible)
                        case .name(let name): [Workspace.get(byName: name.raw)]
                    }
                }
        let trees = workspaces.toSet().sorted { $0.name < $1.name }
            .map { WorkspaceTreeJson(workspace: $0.name, root: .of($0.rootTilingContainer)) }

        return switch args.json {
            case true:
                JSONEncoder.aeroSpaceDefault.encodeToString(trees).map { .succ(io.out($0)) }
                    ?? .fail(io.err("Failed to encode JSON"))
            case false:
                .succ(io.out(trees.flatMap { $0.render() }))
        }
    }
}

private struct WorkspaceTreeJson: Encodable {
    let workspace: String
    let root: TreeNodeJson

    func render() -> [String] {
        ["workspace \(workspace)"] + root.render(depth: 1)
    }
}

/// The tiling tree only. Floating, minimized and fullscreen windows aren't part of it,
/// the same way they aren't part of `flatten-workspace-tree`
private struct TreeNodeJson: Encodable {
    static let windowType = "window"
    static let containerType = "tiling-container"

    let type: String
    let layout: String?
    let windowId: UInt32?
    let children: [TreeNodeJson]?

    enum CodingKeys: String, CodingKey {
        case type
        case layout
        case windowId = "window-id"
        case children
    }

    @MainActor
    static func of(_ node: TreeNode) -> TreeNodeJson {
        switch node.tilingTreeNodeCasesOrDie() {
            case .window(let window):
                TreeNodeJson(type: windowType, layout: nil, windowId: window.windowId, children: nil)
            case .tilingContainer(let container):
                TreeNodeJson(
                    type: containerType,
                    layout: toLayoutString(tc: container),
                    windowId: nil,
                    children: container.children.map { of($0) },
                )
        }
    }

    func render(depth: Int) -> [String] {
        let indent = String(repeating: "  ", count: depth)
        return switch (type, windowId, layout) {
            case (Self.windowType, let windowId?, _): ["\(indent)window \(windowId)"]
            case (_, _, let layout?): ["\(indent)\(layout)"] + (children ?? []).flatMap { $0.render(depth: depth + 1) }
            default: []
        }
    }
}
