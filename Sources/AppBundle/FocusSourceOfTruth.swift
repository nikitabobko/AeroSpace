private var idOfFocusedWindowWhenOwnSourceOfTruth: UInt32? = nil

enum FocusSourceOfTruth {
    case macOs, ownModel
}

func getFocusSourceOfTruth(startup: Bool) -> FocusSourceOfTruth {
    if let nativeFocusedWindow = getNativeFocusedWindow(startup: startup), nativeFocusedWindow.windowId != idOfFocusedWindowWhenOwnSourceOfTruth {
        idOfFocusedWindowWhenOwnSourceOfTruth = nil
        return .macOs
    } else {
        return .ownModel
    }
}

func setFocusSourceOfTruth(_ newValue: FocusSourceOfTruth, startup: Bool) {
    idOfFocusedWindowWhenOwnSourceOfTruth = switch newValue {
        case .macOs: nil
        case .ownModel: getNativeFocusedWindow(startup: startup)?.windowId
    }
}
