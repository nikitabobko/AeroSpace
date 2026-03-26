import CoreGraphics
import Foundation

@MainActor
private var levelCache: [UInt32: MacOsWindowLevel] = [:]

@MainActor
private struct CgWindowInfo {
    let level: MacOsWindowLevel
    let bounds: CGRect
    let ownerPid: pid_t
}

@MainActor
private var cgWindowInfoCache: [UInt32: CgWindowInfo] = [:]

@MainActor
private func refreshCgWindowInfoCache() {
    let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
    guard let cfArray = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [CFDictionary] else { return }

    var levels: [UInt32: MacOsWindowLevel] = [:]
    var infos: [UInt32: CgWindowInfo] = [:]

    for elem in cfArray {
        let dict = elem as NSDictionary

        guard let _windowId = dict[kCGWindowNumber] else { continue }
        let windowId = ((_windowId as! CFNumber) as NSNumber).uint32Value

        guard let _windowLayer = dict[kCGWindowLayer] else { continue }
        let windowLayer = ((_windowLayer as! CFNumber) as NSNumber).intValue

        guard let _pid = dict[kCGWindowOwnerPID] else { continue }
        let pid = ((_pid as! CFNumber) as NSNumber).int32Value

        var bounds = CGRect.zero
        if let boundsDict = dict[kCGWindowBounds] {
            CGRectMakeWithDictionaryRepresentation(boundsDict as! CFDictionary, &bounds)
        }

        let level = MacOsWindowLevel.new(windowLevel: windowLayer)
        levels[windowId] = level
        infos[windowId] = CgWindowInfo(level: level, bounds: bounds, ownerPid: pid)
    }
    levelCache = levels
    cgWindowInfoCache = infos
}

@MainActor
func getWindowLevel(for windowId: UInt32) -> MacOsWindowLevel? {
    if let existing = levelCache[windowId] { return existing }
    refreshCgWindowInfoCache()
    return levelCache[windowId]
}

/// Refresh the CG cache once, then use isLikelyNativeTab for consistent results within a single pass.
@MainActor
func refreshNativeTabDetection() {
    refreshCgWindowInfoCache()
}

/// Count how many windows AeroSpace knows about for a given app PID.
/// Includes tiled, floating, and popup windows.
@MainActor
func windowCountForApp(pid: pid_t) -> Int {
    MacWindow.allWindows.count(where: { $0.macApp.pid == pid })
}

/// Detect macOS native tabs: the AX API reports tabs as separate windows, but only the active
/// tab appears in CGWindowListCopyWindowInfo(.optionOnScreenOnly). If a window is NOT on screen
/// but another window from the same app IS on screen, it's likely an inactive native tab.
/// https://github.com/nikitabobko/AeroSpace/issues/68
///
/// Additional safety: only consider a window as a tab if the same app has at least one OTHER
/// window on-screen with the same PID. This prevents false positives when CG is slow to update.
@MainActor
func isLikelyNativeTab(windowId: UInt32, appPid: pid_t, appWindowCount: Int) -> Bool {
    // If the app only has 1 window known to AeroSpace, it can't be a tab
    if appWindowCount <= 1 { return false }

    // If this window IS on screen, it's either a real window or the active tab — tile it normally.
    if cgWindowInfoCache[windowId] != nil { return false }

    // This window is NOT on screen. Check if the same app has at least one normal window on screen.
    // If so, this off-screen window is likely an inactive native tab.
    for (otherId, info) in cgWindowInfoCache {
        if otherId != windowId && info.ownerPid == appPid && info.level == .normalWindow {
            return true
        }
    }
    return false
}

enum MacOsWindowLevel: Sendable, Equatable {
    case normalWindow
    case alwaysOnTopWindow
    case unknown(windowLevel: Int)

    static func new(windowLevel: Int) -> MacOsWindowLevel {
        switch windowLevel {
            case 0: .normalWindow
            case 3: .alwaysOnTopWindow
            default: .unknown(windowLevel: windowLevel)
        }
    }

    static func fromJson(_ json: Json) -> MacOsWindowLevel? {
        switch json {
            case .string(let str) where str == "normalWindow": .normalWindow
            case .string(let str) where str == "alwaysOnTopWindow": .alwaysOnTopWindow
            case .int(let int): .new(windowLevel: int)
            default: nil
        }
    }

    func toJson() -> Json {
        switch self {
            case .normalWindow: .string("normalWindow")
            case .alwaysOnTopWindow: .string("alwaysOnTopWindow")
            case .unknown(let layerNumber): .int(layerNumber)
        }
    }
}
