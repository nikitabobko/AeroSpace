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
    switch newValue {
    case .macOs:
        idOfFocusedWindowWhenOwnSourceOfTruth = nil
    case .ownModel:
        idOfFocusedWindowWhenOwnSourceOfTruth = getNativeFocusedWindow(startup: startup)?.windowId
    }
}