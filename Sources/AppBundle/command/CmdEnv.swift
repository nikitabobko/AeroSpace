import Common

struct CmdEnv: Copyable { // todo forward env from cli to server
    var windowId: UInt32?
    var workspaceName: String?
    var pwd: String?

    static var defaultEnv: CmdEnv { CmdEnv(windowId: nil, workspaceName: nil, pwd: nil) }
    public init(
        windowId: UInt32?,
        workspaceName: String?,
        pwd: String?
    ) {
        self.windowId = windowId
        self.workspaceName = workspaceName
        self.pwd = pwd
    }

    func withFocus(_ focus: LiveFocus) -> CmdEnv {
        switch focus.asLeaf {
            case .window(let wd): .defaultEnv.copy(\.windowId, wd.windowId)
            case .emptyWorkspace(let ws): .defaultEnv.copy(\.workspaceName, ws.name)
        }
    }

    var asMap: [String: String] {
        var result = config.execConfig.envVariables
        if let pwd {
            result["PWD"] = pwd
        }
        if let windowId {
            result[AEROSPACE_WINDOW_ID] = windowId.description
        }
        if let workspaceName {
            result[AEROSPACE_WORKSPACE] = workspaceName.description
        }
        return result
    }
}
