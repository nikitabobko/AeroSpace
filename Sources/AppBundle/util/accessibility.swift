import AppKit
import Common
import PrivateApi

@MainActor
func waitForAccessibilityPermission_nonCancellable() async {
    let options = [axTrustedCheckOptionPrompt: true]
    while true {
        let status = TrayMenuModel.shared.axPermissionStatus == .waitingWithPrompt
            ? AXIsProcessTrustedWithOptions(options as CFDictionary)
            : AXIsProcessTrusted()
        if status {
            TrayMenuModel.shared.axPermissionStatus = .granted
            break
        }
        if TrayMenuModel.shared.axPermissionStatus == .waitingWithPrompt {
            resetAccessibility() // Because macOS doesn't reset it for us when the app signature changes...
        }
        TrayMenuModel.shared.axPermissionStatus = .waiting
        try? await Task.sleep(for: .seconds(1))
    }
}

private func resetAccessibility() {
    _ = try? Process.run(URL(filePath: "/usr/bin/tccutil"), arguments: ["reset", "Accessibility", aeroSpaceAppId])
}

protocol ReadableAttr: Sendable {
    associatedtype T
    var getter: @Sendable (AnyObject) -> T? { get }
    var key: String { get }
}

protocol WritableAttr: ReadableAttr, Sendable {
    var setter: @Sendable (T) -> CFTypeRef? { get }
}

// Quick reference:
//
// // informational attributes
// kAXRoleAttribute
// kAXSubroleAttribute
// kAXRoleDescriptionAttribute
// kAXTitleAttribute
// kAXDescriptionAttribute
// kAXHelpAttribute
//
// // hierarchy or relationship attributes
// kAXParentAttribute
// kAXChildrenAttribute
// kAXSelectedChildrenAttribute
// kAXVisibleChildrenAttribute
// kAXWindowAttribute
// kAXTopLevelUIElementAttribute
// kAXTitleUIElementAttribute
// kAXServesAsTitleForUIElementsAttribute
// kAXLinkedUIElementsAttribute
// kAXSharedFocusElementsAttribute
//
// // visual state attributes
// kAXEnabledAttribute
// kAXFocusedAttribute
// kAXPositionAttribute
// kAXSizeAttribute
//
// // value attributes
// kAXValueAttribute
// kAXValueDescriptionAttribute
// kAXMinValueAttribute
// kAXMaxValueAttribute
// kAXValueIncrementAttribute
// kAXValueWrapsAttribute
// kAXAllowedValuesAttribute
//
// // text-specific attributes
// kAXSelectedTextAttribute
// kAXSelectedTextRangeAttribute
// kAXSelectedTextRangesAttribute
// kAXVisibleCharacterRangeAttribute
// kAXNumberOfCharactersAttribute
// kAXSharedTextUIElementsAttribute
// kAXSharedCharacterRangeAttribute
//
// // window, sheet, or drawer-specific attributes
// kAXMainAttribute
// kAXMinimizedAttribute
// kAXCloseButtonAttribute
// kAXZoomButtonAttribute
// kAXMinimizeButtonAttribute
// kAXToolbarButtonAttribute
// kAXProxyAttribute
// kAXGrowAreaAttribute
// kAXModalAttribute
// kAXDefaultButtonAttribute
// kAXCancelButtonAttribute
//
// // menu or menu item-specific attributes
// kAXMenuItemCmdCharAttribute
// kAXMenuItemCmdVirtualKeyAttribute
// kAXMenuItemCmdGlyphAttribute
// kAXMenuItemCmdModifiersAttribute
// kAXMenuItemMarkCharAttribute
// kAXMenuItemPrimaryUIElementAttribute
//
// // application element-specific attributes
// kAXMenuBarAttribute
// kAXWindowsAttribute
// kAXFrontmostAttribute
// kAXHiddenAttribute
// kAXMainWindowAttribute
// kAXFocusedWindowAttribute
// kAXFocusedUIElementAttribute
// kAXExtrasMenuBarAttribute
//
// // date/time-specific attributes
// kAXHourFieldAttribute
// kAXMinuteFieldAttribute
// kAXSecondFieldAttribute
// kAXAMPMFieldAttribute
// kAXDayFieldAttribute
// kAXMonthFieldAttribute
// kAXYearFieldAttribute
//
// // table, outline, or browser-specific attributes
// kAXRowsAttribute
// kAXVisibleRowsAttribute
// kAXSelectedRowsAttribute
// kAXColumnsAttribute
// kAXVisibleColumnsAttribute
// kAXSelectedColumnsAttribute
// kAXSortDirectionAttribute
// kAXColumnHeaderUIElementsAttribute
// kAXIndexAttribute
// kAXDisclosingAttribute
// kAXDisclosedRowsAttribute
// kAXDisclosedByRowAttribute
//
// // matte-specific attributes
// kAXMatteHoleAttribute
// kAXMatteContentUIElementAttribute
//
// // ruler-specific attributes
// kAXMarkerUIElementsAttribute
// kAXUnitsAttribute
// kAXUnitDescriptionAttribute
// kAXMarkerTypeAttribute
// kAXMarkerTypeDescriptionAttribute
//
// // miscellaneous or role-specific attributes
// kAXHorizontalScrollBarAttribute
// kAXVerticalScrollBarAttribute
// kAXOrientationAttribute
// kAXHeaderAttribute
// kAXEditedAttribute
// kAXTabsAttribute
// kAXOverflowButtonAttribute
// kAXFilenameAttribute
// kAXExpandedAttribute
// kAXSelectedAttribute
// kAXSplittersAttribute
// kAXContentsAttribute
// kAXNextContentsAttribute
// kAXPreviousContentsAttribute
// kAXDocumentAttribute
// kAXIncrementorAttribute
// kAXDecrementButtonAttribute
// kAXIncrementButtonAttribute
// kAXColumnTitleAttribute
// kAXURLAttribute
// kAXLabelUIElementsAttribute
// kAXLabelValueAttribute
// kAXShownMenuUIElementAttribute
// kAXIsApplicationRunningAttribute
// kAXFocusedApplicationAttribute
// kAXElementBusyAttribute
// kAXAlternateUIVisibleAttribute
enum Ax {
    struct ReadableAttrImpl<T>: ReadableAttr {
        var key: String
        var getter: @Sendable (AnyObject) -> T?
    }

    struct WritableAttrImpl<T>: WritableAttr {
        var key: String
        var getter: @Sendable (AnyObject) -> T?
        var setter: @Sendable (T) -> CFTypeRef?
    }

    static let parentWindowRecursive = ReadableAttrImpl<AXUIElement>(
        key: kAXWindowAttribute,
        getter: { ($0 as! AXUIElement) },
    )
    static let titleAttr = WritableAttrImpl<String>(
        key: kAXTitleAttribute,
        getter: { $0 as? String },
        setter: { $0 as CFTypeRef },
    )
    static let roleAttr = WritableAttrImpl<String>(
        key: kAXRoleAttribute,
        getter: { $0 as? String },
        setter: { $0 as CFTypeRef },
    )
    static let subroleAttr = WritableAttrImpl<String>(
        key: kAXSubroleAttribute,
        getter: { $0 as? String },
        setter: { $0 as CFTypeRef },
    )
    static let identifierAttr = ReadableAttrImpl<String>(
        key: kAXIdentifierAttribute,
        getter: { $0 as? String },
    )
    // static let modalAttr = ReadableAttrImpl<Bool>(
    //     key: kAXModalAttribute,
    //     getter: { $0 as? Bool },
    // )
    static let enabledAttr = ReadableAttrImpl<Bool>(
        key: kAXEnabledAttribute,
        getter: { $0 as? Bool },
    )
    static let enhancedUserInterfaceAttr = WritableAttrImpl<Bool>(
        key: "AXEnhancedUserInterface",
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef },
    )
    static let minimizedAttr = WritableAttrImpl<Bool>(
        key: kAXMinimizedAttribute,
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef },
    )
    //static let minimizedAttr = ReadableAttrImpl<Bool>(
    //    key: kAXMinimizedAttribute,
    //    getter: { $0 as? Bool }
    //)
    static let isFullscreenAttr = WritableAttrImpl<Bool>(
        key: "AXFullScreen",
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef },
    )
    static let isFocused = ReadableAttrImpl<Bool>(
        key: kAXFocusedAttribute,
        getter: { $0 as? Bool },
    )
    static let isMainAttr = WritableAttrImpl<Bool>(
        key: kAXMainAttribute,
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef },
    )
    static let sizeAttr = WritableAttrImpl<CGSize>(
        key: kAXSizeAttribute,
        getter: {
            var raw: CGSize = .zero
            check(unsafe AXValueGetValue($0 as! AXValue, .cgSize, &raw))
            return raw
        },
        setter: {
            var size = $0
            return unsafe AXValueCreate(.cgSize, &size) as CFTypeRef
        },
    )
    static let topLeftCornerAttr = WritableAttrImpl<CGPoint>(
        key: kAXPositionAttribute,
        getter: {
            var raw: CGPoint = .zero
            check(unsafe AXValueGetValue($0 as! AXValue, .cgPoint, &raw))
            return raw
        },
        setter: {
            var size = $0
            return unsafe AXValueCreate(.cgPoint, &size) as CFTypeRef
        },
    )
    /// Returns windows visible on all monitors
    /// If some windows are located on not active macOS Spaces then they won't be returned
    static let windowsAttr = ReadableAttrImpl<[WindowIdAndAxUiElement]>(
        key: kAXWindowsAttribute,
        getter: { ($0 as? NSArray)?.compactMap(windowOrNil).map { ($0.windowId, $0.ax.cast) } ?? [] },
    )
    static let focusedWindowAttr = ReadableAttrImpl<WindowIdAndAxUiElementMock>(
        key: kAXFocusedWindowAttribute,
        getter: windowOrNil,
    )
    //static let mainWindowAttr = ReadableAttrImpl<AXUIElement>(
    //    key: kAXMainWindowAttribute,
    //    getter: tryGetWindow
    //)
    static let closeButtonAttr = ReadableAttrImpl<any AxUiElementMock>(
        key: kAXCloseButtonAttribute,
        getter: castToAxUiElementMock,
    )
    // Note! fullscreen is not the same as "zoom" (green plus)
    static let fullscreenButtonAttr = ReadableAttrImpl<any AxUiElementMock>(
        key: kAXFullScreenButtonAttribute,
        getter: castToAxUiElementMock,
    )
    // green plus
    static let zoomButtonAttr = ReadableAttrImpl<any AxUiElementMock>(
        key: kAXZoomButtonAttribute,
        getter: castToAxUiElementMock,
    )
    static let minimizeButtonAttr = ReadableAttrImpl<any AxUiElementMock>(
        key: kAXMinimizeButtonAttribute,
        getter: castToAxUiElementMock,
    )
    //static let growAreaAttr = ReadableAttrImpl<AXUIElement>(
    //    key: kAXGrowAreaAttribute,
    //    getter: { ($0 as! AXUIElement) }
    //)
}

let kAXAeroSynthetic = "Aero.synthetic"

private func castToAxUiElementMock(_ a: AnyObject) -> AxUiElementMock {
    if isUnitTest {
        if let str = a as? String, let commaIndex = str.firstIndex(of: ",") {
            let windowId = UInt32.init(String(str.prefix(upTo: commaIndex)).removePrefix("AXUIElement(AxWindowId="))
            if let windowId {
                return castToAxUiElementMock([
                    "Aero.axWindowId": Json.int(windowId),
                    kAXAeroSynthetic: Json.bool(true),
                ] as AnyObject)
            }
        }
        if let dict = a as? [String: Json] { // Convert from _SwiftDeferredNSDictionary<String, Json>
            return dict as? AxUiElementMock ?? dieT("Cannot cast \(type(of: a)) to AxUiElementMock")
        }
        die("Can't convert \(a) to AxUiElementMock")
    }
    return a as! AXUIElement
}

typealias WindowIdAndAxUiElement = (windowId: UInt32, ax: AXUIElement)
typealias WindowIdAndAxUiElementMock = (windowId: UInt32, ax: AxUiElementMock)

private func windowOrNil(_ any: Any?) -> WindowIdAndAxUiElementMock? {
    guard let any else { return nil }
    let potentialWindow = castToAxUiElementMock(any as AnyObject)
    // Filter out non-window objects (e.g. Finder's desktop)
    return switch potentialWindow.containingWindowId() {
        case let windowId?: (windowId, potentialWindow)
        case nil: nil
    }
}

struct AxAppCircuitBreakerState {
    static let cooldownDuration: Duration = .seconds(1)

    private var unresponsiveUntil: [pid_t: ContinuousClock.Instant] = [:]

    mutating func recordTimeout(
        for pid: pid_t,
        now: ContinuousClock.Instant,
    ) {
        unresponsiveUntil[pid] = now.advanced(by: Self.cooldownDuration)
    }

    mutating func shouldSkipRequests(
        for pid: pid_t,
        now: ContinuousClock.Instant,
    ) -> Bool {
        guard let deadline = unresponsiveUntil[pid] else { return false }
        if now < deadline { return true }
        unresponsiveUntil[pid] = nil
        return false
    }
}

private final class AxAppCircuitBreaker: @unchecked Sendable {
    private let clock = ContinuousClock()
    private let lock = NSLock()
    private var state = AxAppCircuitBreakerState()

    func recordTimeout(for pid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        state.recordTimeout(for: pid, now: clock.now)
    }

    func shouldSkipRequests(for pid: pid_t) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return state.shouldSkipRequests(for: pid, now: clock.now)
    }
}

private let axAppCircuitBreaker = AxAppCircuitBreaker()

func shouldSkipAxRequests(for pid: pid_t) -> Bool {
    axAppCircuitBreaker.shouldSkipRequests(for: pid)
}

func recordAxError(_ error: AXError) {
    if error == .cannotComplete, let pid = axTaskLocalAppThreadToken?.pid {
        axAppCircuitBreaker.recordTimeout(for: pid)
    }
}

extension AXUIElement: AxUiElementMock {
    func get<Attr: ReadableAttr>(_ attr: Attr) -> Attr.T? {
        getWithError(attr).value
    }

    func getWithError<Attr: ReadableAttr>(_ attr: Attr) -> (value: Attr.T?, error: AXError) {
        let state = signposter.beginInterval(#function, "attr: \(attr.key) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
        defer { signposter.endInterval(#function, state) }
        var raw: AnyObject?
        let error = unsafe AXUIElementCopyAttributeValue(self, attr.key as CFString, &raw)
        recordAxError(error)
        return (error == .success ? raw.flatMap(attr.getter) : nil, error)
    }

    @discardableResult func set<Attr: WritableAttr>(_ attr: Attr, _ value: Attr.T) -> Bool {
        if serverArgs.isReadOnly { return false }
        let state = signposter.beginInterval(#function, "attr: \(attr.key) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
        defer { signposter.endInterval(#function, state) }
        guard let value = attr.setter(value) else { return false }
        let error = AXUIElementSetAttributeValue(self, attr.key as CFString, value)
        recordAxError(error)
        return error == .success
    }

    @discardableResult func perform(_ action: String) -> Bool {
        if serverArgs.isReadOnly { return false }
        let state = signposter.beginInterval(#function, "action: \(action) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
        defer { signposter.endInterval(#function, state) }
        let error = AXUIElementPerformAction(self, action as CFString)
        recordAxError(error)
        return error == .success
    }

    func containingWindowId() -> CGWindowID? {
        containingWindowIdWithError().windowId
    }

    func containingWindowIdWithError() -> (windowId: CGWindowID?, error: AXError) {
        let state = signposter.beginInterval(#function, "axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
        defer { signposter.endInterval(#function, state) }
        var cgWindowId = CGWindowID()
        let error = unsafe _AXUIElementGetWindow(self, &cgWindowId)
        recordAxError(error)
        return (error == .success && cgWindowId != kCGNullWindowID ? cgWindowId : nil, error)
    }
}

extension AXObserver {
    static func new(_ pid: pid_t, _ handler: AXObserverCallback) -> AXObserver? {
        var observer: AXObserver? = nil
        return unsafe AXObserverCreate(pid, handler, &observer) == .success ? observer : nil
    }
}
