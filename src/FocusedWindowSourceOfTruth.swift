private var idOfFocusedWindowWhenOwnSourceOfTruth: UInt32? = nil

enum FocusedWindowSourceOfTruth {
    case macOs, ownModel

    static let defaultSourceOfTruth: FocusedWindowSourceOfTruth = .macOs
}

var focusedWindowSourceOfTruth: FocusedWindowSourceOfTruth {
    set {
        switch newValue {
        case .macOs:
            idOfFocusedWindowWhenOwnSourceOfTruth = nil
        case .ownModel:
            idOfFocusedWindowWhenOwnSourceOfTruth = nativeFocusedWindow?.windowId
        }
    }
    get {
        if let nativeFocusedWindow, nativeFocusedWindow.windowId != idOfFocusedWindowWhenOwnSourceOfTruth {
            idOfFocusedWindowWhenOwnSourceOfTruth = nil
            return .macOs
        } else {
            return .ownModel
        }
    }
}
