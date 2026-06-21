import Common

struct CmdEnv {
    var windowId: UInt32? = nil
    var workspaceName: String? = nil

    static let defaultEnv: CmdEnv = .init()

    consuming func withFocus(_ focus: LiveFocus) -> Self {
        return switch focus.asLeaf {
            case .window(let wd): withWindowId(wd.windowId)
            case .emptyWorkspace(let ws): withWorkspaceName(ws.name)
        }
    }

    consuming func withWindowId(_ windowId: UInt32) -> CmdEnv {
        self.windowId = windowId
        self.workspaceName = nil
        return self
    }

    consuming func withWorkspaceName(_ workspaceName: String) -> CmdEnv {
        self.windowId = nil
        self.workspaceName = workspaceName
        return self
    }

    var asMap: [String: String] {
        var result = [String: String]()
        if let windowId {
            result[AEROSPACE_WINDOW_ID] = windowId.description
        }
        if let workspaceName {
            result[AEROSPACE_WORKSPACE] = workspaceName.description
        }
        return result
    }
}
