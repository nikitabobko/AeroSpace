private var idOfFocusedWindowWhenOwnSourceOfTruth: UInt32? = nil

enum FocusedWorkspaceSourceOfTruth {
    case macOs, ownModel

    static let defaultSourceOfTruth: FocusedWorkspaceSourceOfTruth = .macOs
}

var focusedWorkspaceSourceOfTruth: FocusedWorkspaceSourceOfTruth {
    set {
        switch newValue {
        case .macOs:
            idOfFocusedWindowWhenOwnSourceOfTruth = nil
        case .ownModel:
            idOfFocusedWindowWhenOwnSourceOfTruth = focusedWindow?.windowId
        }
    }
    get {
        if let focusedWindow, focusedWindow.windowId != idOfFocusedWindowWhenOwnSourceOfTruth {
            idOfFocusedWindowWhenOwnSourceOfTruth = nil
            return .macOs
        } else {
            return .ownModel
        }
    }
}
