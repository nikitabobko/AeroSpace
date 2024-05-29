import Common
import AppKit

func checkAccessibilityPermissions() {
    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
    if !AXIsProcessTrustedWithOptions(options as CFDictionary) {
        resetAccessibility() // Because macOS doesn't reset it for us when the app signature changes...
        terminateApp()
    }
}

private func resetAccessibility() {
    _ = try? Process.run(URL(filePath: "/usr/bin/tccutil"), arguments: ["reset", "Accessibility", Bundle.appId])
}

protocol ReadableAttr {
    associatedtype T
    var getter: (AnyObject) -> T? { get }
    var key: String { get }
}

protocol WritableAttr: ReadableAttr {
    var setter: (T) -> CFTypeRef? { get }
}

/*
	Quick reference:

	// informational attributes
	kAXRoleAttribute
	kAXSubroleAttribute
	kAXRoleDescriptionAttribute
	kAXTitleAttribute
	kAXDescriptionAttribute
	kAXHelpAttribute

	// hierarchy or relationship attributes
	kAXParentAttribute
	kAXChildrenAttribute
	kAXSelectedChildrenAttribute
	kAXVisibleChildrenAttribute
	kAXWindowAttribute
	kAXTopLevelUIElementAttribute
	kAXTitleUIElementAttribute
	kAXServesAsTitleForUIElementsAttribute
	kAXLinkedUIElementsAttribute
    kAXSharedFocusElementsAttribute

	// visual state attributes
	kAXEnabledAttribute
	kAXFocusedAttribute
	kAXPositionAttribute
	kAXSizeAttribute

	// value attributes
	kAXValueAttribute
    kAXValueDescriptionAttribute
	kAXMinValueAttribute
	kAXMaxValueAttribute
	kAXValueIncrementAttribute
	kAXValueWrapsAttribute
	kAXAllowedValuesAttribute

	// text-specific attributes
	kAXSelectedTextAttribute
	kAXSelectedTextRangeAttribute
    kAXSelectedTextRangesAttribute
	kAXVisibleCharacterRangeAttribute
	kAXNumberOfCharactersAttribute
	kAXSharedTextUIElementsAttribute
	kAXSharedCharacterRangeAttribute

	// window, sheet, or drawer-specific attributes
	kAXMainAttribute
	kAXMinimizedAttribute
	kAXCloseButtonAttribute
	kAXZoomButtonAttribute
	kAXMinimizeButtonAttribute
	kAXToolbarButtonAttribute
	kAXProxyAttribute
	kAXGrowAreaAttribute
	kAXModalAttribute
	kAXDefaultButtonAttribute
	kAXCancelButtonAttribute

	// menu or menu item-specific attributes
	kAXMenuItemCmdCharAttribute
	kAXMenuItemCmdVirtualKeyAttribute
	kAXMenuItemCmdGlyphAttribute
	kAXMenuItemCmdModifiersAttribute
	kAXMenuItemMarkCharAttribute
	kAXMenuItemPrimaryUIElementAttribute

	// application element-specific attributes
	kAXMenuBarAttribute
	kAXWindowsAttribute
	kAXFrontmostAttribute
	kAXHiddenAttribute
	kAXMainWindowAttribute
	kAXFocusedWindowAttribute
	kAXFocusedUIElementAttribute
	kAXExtrasMenuBarAttribute

	// date/time-specific attributes
	kAXHourFieldAttribute
	kAXMinuteFieldAttribute
	kAXSecondFieldAttribute
	kAXAMPMFieldAttribute
	kAXDayFieldAttribute
	kAXMonthFieldAttribute
	kAXYearFieldAttribute

	// table, outline, or browser-specific attributes
	kAXRowsAttribute
	kAXVisibleRowsAttribute
	kAXSelectedRowsAttribute
	kAXColumnsAttribute
	kAXVisibleColumnsAttribute
	kAXSelectedColumnsAttribute
	kAXSortDirectionAttribute
	kAXColumnHeaderUIElementsAttribute
	kAXIndexAttribute
	kAXDisclosingAttribute
	kAXDisclosedRowsAttribute
	kAXDisclosedByRowAttribute

	// matte-specific attributes
	kAXMatteHoleAttribute
	kAXMatteContentUIElementAttribute

	// ruler-specific attributes
	kAXMarkerUIElementsAttribute
	kAXUnitsAttribute
	kAXUnitDescriptionAttribute
	kAXMarkerTypeAttribute
	kAXMarkerTypeDescriptionAttribute

	// miscellaneous or role-specific attributes
	kAXHorizontalScrollBarAttribute
	kAXVerticalScrollBarAttribute
	kAXOrientationAttribute
	kAXHeaderAttribute
	kAXEditedAttribute
	kAXTabsAttribute
	kAXOverflowButtonAttribute
	kAXFilenameAttribute
	kAXExpandedAttribute
	kAXSelectedAttribute
	kAXSplittersAttribute
	kAXContentsAttribute
	kAXNextContentsAttribute
	kAXPreviousContentsAttribute
	kAXDocumentAttribute
	kAXIncrementorAttribute
	kAXDecrementButtonAttribute
	kAXIncrementButtonAttribute
	kAXColumnTitleAttribute
	kAXURLAttribute
	kAXLabelUIElementsAttribute
	kAXLabelValueAttribute
	kAXShownMenuUIElementAttribute
	kAXIsApplicationRunningAttribute
	kAXFocusedApplicationAttribute
 	kAXElementBusyAttribute
	kAXAlternateUIVisibleAttribute
*/
enum Ax {
    struct ReadableAttrImpl<T>: ReadableAttr {
        var key: String
        var getter: (AnyObject) -> T?
    }

    struct WritableAttrImpl<T>: WritableAttr {
        var key: String
        var getter: (AnyObject) -> T?
        var setter: (T) -> CFTypeRef?
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
    static let windowsAttr = ReadableAttrImpl<[AXUIElement]>(
        key: kAXWindowsAttribute,
        getter: { ($0 as! NSArray).compactMap(tryGetWindow) }
    )
    static let focusedWindowAttr = ReadableAttrImpl<AXUIElement>(
        key: kAXFocusedWindowAttribute,
        getter: tryGetWindow
    )
    //static let mainWindowAttr = ReadableAttrImpl<AXUIElement>(
    //    key: kAXMainWindowAttribute,
    //    getter: tryGetWindow
    //)
    static let closeButtonAttr = ReadableAttrImpl<AXUIElement>(
        key: kAXCloseButtonAttribute,
        getter: { ($0 as! AXUIElement) }
    )
    // Note! fullscreen is not the same as "zoom" (green plus)
    static let fullscreenButtonAttr = ReadableAttrImpl<AXUIElement>(
        key: kAXFullScreenButtonAttribute,
        getter: { ($0 as! AXUIElement) }
    )
    static let zoomButtonAttr = ReadableAttrImpl<AXUIElement>(
        key: kAXZoomButtonAttribute,
        getter: { ($0 as! AXUIElement) }
    )
    static let minimizeButtonAttr = ReadableAttrImpl<AXUIElement>(
        key: kAXMinimizeButtonAttribute,
        getter: { ($0 as! AXUIElement) }
    )
    //static let growAreaAttr = ReadableAttrImpl<AXUIElement>(
    //    key: kAXGrowAreaAttribute,
    //    getter: { ($0 as! AXUIElement) }
    //)
}

private func tryGetWindow(_ any: Any?) -> AXUIElement? {
    guard let any else { return nil }
    let potentialWindow = any as! AXUIElement
    // Filter out non-window objects (e.g. Finder's desktop)
    return potentialWindow.containingWindowId() != nil ? potentialWindow : nil
}

extension AXUIElement {
    func get<Attr: ReadableAttr>(_ attr: Attr) -> Attr.T? {
        var raw: AnyObject?
        return AXUIElementCopyAttributeValue(self, attr.key as CFString, &raw) == .success ? attr.getter(raw!) : nil
    }

    @discardableResult func set<Attr: WritableAttr>(_ attr: Attr, _ value: Attr.T) -> Bool {
        guard let value = attr.setter(value) else { return false }
        return AXUIElementSetAttributeValue(self, attr.key as CFString, value) == .success
    }

    func containingWindowId() -> CGWindowID? {
        bridgedHeader.containingWindowId(self)
    }

    var center: CGPoint? {
        guard let topLeft = get(Ax.topLeftCornerAttr) else { return nil }
        guard let size = get(Ax.sizeAttr) else { return nil }
        return CGPoint(x: topLeft.x + size.width / 2, y: topLeft.y + size.height)
    }

    func raise() -> Bool {
        AXUIElementPerformAction(self, kAXRaiseAction as CFString) == AXError.success
    }
}

extension AXObserver {
    private static func newImpl(_ pid: pid_t, _ handler: AXObserverCallback) -> AXObserver? {
        var observer: AXObserver? = nil
        return AXObserverCreate(pid, handler, &observer) == .success ? observer : nil
    }

    static func observe(_ pid: pid_t, _ notifKey: String, _ ax: AXUIElement, _ handler: AXObserverCallback, data: AnyObject?) -> AXObserver? {
        guard let observer = newImpl(pid, handler) else { return nil }
        let dataPtr: UnsafeMutableRawPointer? = data.flatMap { Unmanaged.passUnretained($0).toOpaque() }
        // kAXWindowCreatedNotification takes more than 1 attempt to subscribe. Probably, it's because the application
        // is still initializing
        for _ in 1...SUBSCRIBE_OBSERVER_ATTEMPTS_THRESHOLD {
            if AXObserverAddNotification(observer, ax, notifKey as CFString, dataPtr) == .success {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
                return observer
            }
        }
        return nil
    }
}

struct AxObserverWrapper {
    let obs: AXObserver
    let ax: AXUIElement
    let notif: CFString
}

/// Pure heuristic. Usually it takes around 1000 attempts to subscribe
private let SUBSCRIBE_OBSERVER_ATTEMPTS_THRESHOLD = 1 // todo drop
