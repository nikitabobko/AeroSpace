private var pidOfFocusedAppWhenOwnSourceOfTruth: Int32? = nil

enum FocusedWorkspaceSourceOfTruth {
    case macOs, ownModel

    static let defaultSourceOfTruth: FocusedWorkspaceSourceOfTruth = .macOs
}

var focusedWorkspaceSourceOfTruth: FocusedWorkspaceSourceOfTruth {
    set {
        switch newValue {
        case .macOs:
            pidOfFocusedAppWhenOwnSourceOfTruth = nil
        case .ownModel:
            pidOfFocusedAppWhenOwnSourceOfTruth = focusedApp?.id
        }
    }
    get {
        if pidOfFocusedAppWhenOwnSourceOfTruth != focusedApp?.id {
            pidOfFocusedAppWhenOwnSourceOfTruth = nil
            return .macOs
        } else {
            return .ownModel
        }
    }
}
