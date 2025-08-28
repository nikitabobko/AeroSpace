import AppKit
import Common
import PrivateApi

@MainActor
func checkAccessibilityPermissions() {
    let options = [axTrustedCheckOptionPrompt: true]
    if !AXIsProcessTrustedWithOptions(options as CFDictionary) {
        resetAccessibility() // Because macOS doesn't reset it for us when the app signature changes...
        terminateApp()
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

    static let titleAttr = WritableAttrImpl<String>(
        key: kAXTitleAttribute,
        getter: { $0 as? String },
        setter: { $0 as CFTypeRef }
    )
    static let roleAttr = WritableAttrImpl<String>(
        key: kAXRoleAttribute,
        getter: { $0 as? String },
        setter: { $0 as CFTypeRef }
    )
    static let subroleAttr = WritableAttrImpl<String>(
        key: kAXSubroleAttribute,
        getter: { $0 as? String },
        setter: { $0 as CFTypeRef }
    )
    static let identifierAttr = ReadableAttrImpl<String>(
        key: kAXIdentifierAttribute,
        getter: { $0 as? String }
    )
    static let modalAttr = ReadableAttrImpl<Bool>(
        key: kAXModalAttribute,
        getter: { $0 as? Bool }
    )
    static let enabledAttr = ReadableAttrImpl<Bool>(
        key: kAXEnabledAttribute,
        getter: { $0 as? Bool }
    )
    static let enhancedUserInterfaceAttr = WritableAttrImpl<Bool>(
        key: "AXEnhancedUserInterface",
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef }
    )
    static let minimizedAttr = WritableAttrImpl<Bool>(
        key: kAXMinimizedAttribute,
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef }
    )
    //static let minimizedAttr = ReadableAttrImpl<Bool>(
    //    key: kAXMinimizedAttribute,
    //    getter: { $0 as? Bool }
    //)
    static let isFullscreenAttr = WritableAttrImpl<Bool>(
        key: "AXFullScreen",
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef }
    )
    static let isFocused = ReadableAttrImpl<Bool>(
        key: kAXFocusedAttribute,
        getter: { $0 as? Bool }
    )
    static let isMainAttr = WritableAttrImpl<Bool>(
        key: kAXMainAttribute,
        getter: { $0 as? Bool },
        setter: { $0 as CFTypeRef }
    )
    static let sizeAttr = WritableAttrImpl<CGSize>(
        key: kAXSizeAttribute,
        getter: {
            var raw: CGSize = .zero
            check(AXValueGetValue($0 as! AXValue, .cgSize, &raw))
            return raw
        },
        setter: {
            var size = $0
            return AXValueCreate(.cgSize, &size) as CFTypeRef
        }
    )
    static let topLeftCornerAttr = WritableAttrImpl<CGPoint>(
        key: kAXPositionAttribute,
        getter: {
            var raw: CGPoint = .zero
            AXValueGetValue($0 as! AXValue, .cgPoint, &raw)
            return raw
        },
        setter: {
            var size = $0
            return AXValueCreate(.cgPoint, &size) as CFTypeRef
        }
    )
    /// Returns windows visible on all monitors
    /// If some windows are located on not active macOS Spaces then they won't be returned
    static let windowsAttr = ReadableAttrImpl<[WindowIdAndAxUiElement]>(
        key: kAXWindowsAttribute,
        getter: { ($0 as? NSArray)?.compactMap(windowOrNil).map { ($0.windowId, $0.ax.cast) } ?? [] }
    )
    static let focusedWindowAttr = ReadableAttrImpl<WindowIdAndAxUiElementMock>(
        key: kAXFocusedWindowAttribute,
        getter: windowOrNil
    )
    //static let mainWindowAttr = ReadableAttrImpl<AXUIElement>(
    //    key: kAXMainWindowAttribute,
    //    getter: tryGetWindow
    //)
    static let closeButtonAttr = ReadableAttrImpl<any AxUiElementMock>(
        key: kAXCloseButtonAttribute,
        getter: castToAxUiElementMock
    )
    // Note! fullscreen is not the same as "zoom" (green plus)
    static let fullscreenButtonAttr = ReadableAttrImpl<any AxUiElementMock>(
        key: kAXFullScreenButtonAttribute,
        getter: castToAxUiElementMock
    )
    // green plus
    static let zoomButtonAttr = ReadableAttrImpl<any AxUiElementMock>(
        key: kAXZoomButtonAttribute,
        getter: castToAxUiElementMock
    )
    static let minimizeButtonAttr = ReadableAttrImpl<any AxUiElementMock>(
        key: kAXMinimizeButtonAttribute,
        getter: castToAxUiElementMock
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
                    "Aero.axWindowId": Json.uint32(windowId),
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
    let windowId = potentialWindow.containingWindowId()
    if let windowId {
        return (windowId, potentialWindow)
    } else {
        return nil
    }
}

extension AXUIElement: AxUiElementMock {
    func get<Attr: ReadableAttr>(_ attr: Attr) -> Attr.T? {
        let state = signposter.beginInterval(#function, "attr: \(attr.key) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
        defer { signposter.endInterval(#function, state) }
        var raw: AnyObject?
        return AXUIElementCopyAttributeValue(self, attr.key as CFString, &raw) == .success
            ? raw.flatMap(attr.getter)
            : nil
    }

    @discardableResult func set<Attr: WritableAttr>(_ attr: Attr, _ value: Attr.T) -> Bool {
        if serverArgs.isReadOnly { return false }
        let state = signposter.beginInterval(#function, "attr: \(attr.key) axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
        defer { signposter.endInterval(#function, state) }
        guard let value = attr.setter(value) else { return false }
        return AXUIElementSetAttributeValue(self, attr.key as CFString, value) == .success
    }

    func containingWindowId() -> CGWindowID? {
        let state = signposter.beginInterval(#function, "axTaskLocalAppThreadToken: \(axTaskLocalAppThreadToken?.idForDebug)")
        defer { signposter.endInterval(#function, state) }
        var cgWindowId = CGWindowID()
        return _AXUIElementGetWindow(self, &cgWindowId) == .success ? cgWindowId : nil
    }
}

extension AXObserver {
    static func new(_ pid: pid_t, _ handler: AXObserverCallback) -> AXObserver? {
        var observer: AXObserver? = nil
        return AXObserverCreate(pid, handler, &observer) == .success ? observer : nil
    }
}
