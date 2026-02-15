import AppKit
import Common
import Foundation

struct GetTreeCommand: Command {
    let args: GetTreeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let workspace = target.workspace

        let tilingJson = serializeContainer(workspace.rootTilingContainer)
        let floatingJson: [Json] = workspace.floatingWindows.map { serializeWindow($0) }

        let root: Json = .dict([
            "type": .string("workspace"),
            "name": .string(workspace.name),
            "tiling": tilingJson,
            "floating": .array(floatingJson),
        ])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(root),
              let jsonString = String(data: data, encoding: .utf8)
        else {
            return io.err("Failed to serialize workspace tree to JSON")
        }
        return io.out(jsonString)
    }
}

@MainActor
private func serializeContainer(_ container: TilingContainer) -> Json {
    let children: [Json] = container.children.map { child in
        switch child.nodeCases {
            case .window(let w):
                return serializeWindow(w)
            case .tilingContainer(let c):
                return serializeContainer(c)
            case .workspace,
                 .macosMinimizedWindowsContainer,
                 .macosHiddenAppsWindowsContainer,
                 .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer:
                die("Unexpected child type in tiling container")
        }
    }

    let layoutStr: String = container.layout.rawValue
    let orientationStr: String = switch container.orientation {
        case .h: "horizontal"
        case .v: "vertical"
    }

    return .dict([
        "type": .string("container"),
        "layout": .string(layoutStr),
        "orientation": .string(orientationStr),
        "children": .array(children),
    ])
}

@MainActor
private func serializeWindow(_ window: Window) -> Json {
    return .dict([
        "type": .string("window"),
        "window-id": .uint32(window.windowId),
        "app-bundle-id": .string(window.app.rawAppBundleId ?? ""),
        "app-name": .string(window.app.name ?? ""),
    ])
}
