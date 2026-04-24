import AppKit
import AutoRaiseCore
import Common

struct AutoRaiseConfig: ConvenienceCopyable, Equatable, Sendable {
    var enabled: Bool = false
    var pollMillis: Int = 8
    var ignoreSpaceChanged: Bool = false
    var invertDisableKey: Bool = false
    var invertIgnoreApps: Bool = false
    var ignoreApps: [String] = []
    var ignoreTitles: [String] = []
    var stayFocusedBundleIds: [String] = []
    var disableKey: AutoRaiseDisableKey = .control
}

enum AutoRaiseDisableKey: String, Equatable, Sendable {
    case control, option, disabled

    // CGEventFlags mask. Upstream AutoRaise checks modifier state via
    // CGEventGetFlags(keyDownEvent) & disableKey.
    var cgEventFlagMask: Int32 {
        switch self {
            case .control: Int32(CGEventFlags.maskControl.rawValue)
            case .option: Int32(CGEventFlags.maskAlternate.rawValue)
            case .disabled: 0
        }
    }
}

extension AutoRaiseConfig {
    func toBridge() -> AutoRaiseBridgeConfig {
        let bridge = AutoRaiseBridgeConfig()
        bridge.pollMillis = Int32(pollMillis)
        bridge.disableKey = disableKey.cgEventFlagMask
        bridge.ignoreSpaceChanged = ignoreSpaceChanged
        bridge.invertDisableKey = invertDisableKey
        bridge.invertIgnoreApps = invertIgnoreApps
        bridge.ignoreApps = ignoreApps
        bridge.ignoreTitles = ignoreTitles
        bridge.stayFocusedBundleIds = stayFocusedBundleIds
        return bridge
    }
}
