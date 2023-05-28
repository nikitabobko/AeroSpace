import Foundation

func checkAccessibilityPermissions() {
    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
    if !AXIsProcessTrustedWithOptions(options as CFDictionary) {
        fatalError("Accessibility permission isn't granted")
    }
}

protocol ReadableAttr {
    associatedtype T
    var getter: (AnyObject) -> T { get }
    var value: String { get }
}

protocol WritableAttr : ReadableAttr {
    var setter: (T) -> CFTypeRef { get }
}

enum Ax {
    struct ReadableAttrImpl<T>: ReadableAttr {
        var value: String
        var getter: (AnyObject) -> T
    }

    struct WritableAttrImpl<T>: WritableAttr {
        var value: String
        var getter: (AnyObject) -> T
        var setter: (T) -> CFTypeRef
    }

    // todo wip
    static let valueAttr = ReadableAttrImpl<String>(
            value: kAXValueAttribute,
            getter: { foo in
                print(stringType(of: foo))
                return ""
            }
    )
    static let titleAttr = WritableAttrImpl<String>(
            value: kAXTitleAttribute,
            getter: { $0 as? String ?? errorT("kAXTitleAttribute error") },
            setter: { $0 as CFTypeRef }
    )
    static let sizeAttr = WritableAttrImpl<CGSize>(
            value: kAXSizeAttribute,
            getter: {
                var raw: CGSize = .zero
                // I'd be happy to use safe cast, but I can't :(
                //      "Conditional downcast to CoreFoundation type 'AXValue' will always succeed"
                assert(AXValueGetValue($0 as! AXValue, .cgSize, &raw))
                return raw
            },
            setter: {
                var size = $0
                return AXValueCreate(.cgSize, &size) as CFTypeRef
            }
    )
    static let positionAttr = WritableAttrImpl<CGPoint>(
            value: kAXPositionAttribute,
            getter: {
                var raw: CGPoint = .zero
                // I'd be happy to use safe cast, but I can't :(
                //      "Conditional downcast to CoreFoundation type 'AXValue' will always succeed"
                AXValueGetValue($0 as! AXValue, .cgPoint, &raw)
                return raw
            },
            setter: {
                var size = $0
                return AXValueCreate(.cgPoint, &size) as CFTypeRef
            }
    )
    static let windowsAttr = ReadableAttrImpl<[AXUIElement]>(
            value: kAXWindowsAttribute,
            getter: {
                ($0 as? NSArray ?? errorT("kAXWindowsAttribute error"))
                        // I'd be happy to use safe cast, but I can't :(
                        //      "Conditional downcast to CoreFoundation type 'AXValue' will always succeed"
                        .compactMap { $0 as! AXUIElement }
            }
    )
    // todo unused?
    static let focusedWindowAttr = ReadableAttrImpl<AXUIElement>(
            value: kAXFocusedWindowAttribute,
            // I'd be happy to use safe cast, but I can't :(
            //      "Conditional downcast to CoreFoundation type 'AXValue' will always succeed"
            getter: { $0 as! AXUIElement }
    )
    static let closeButtonAttr = ReadableAttrImpl<AXUIElement>(
            value: kAXCloseButtonAttribute,
            // I'd be happy to use safe cast, but I can't :(
            //      "Conditional downcast to CoreFoundation type 'AXValue' will always succeed"
            getter: { $0 as! AXUIElement }
    )
}

func errorT<T>(_ message: String = "") -> T {
    fatalError(message)
}

extension AXUIElement {
    func get<Attr: ReadableAttr>(_ attr: Attr) -> Attr.T? {
        var raw: AnyObject?
        return AXUIElementCopyAttributeValue(self, attr.value as CFString, &raw) == .success
                ? attr.getter(raw!)
                : nil
    }

    func set<Attr: WritableAttr>(_ attr: Attr, _ value: Attr.T) -> Bool {
        AXUIElementSetAttributeValue(self, attr.value as CFString, attr.setter(value)) == .success
    }

    func windowId() -> CGWindowID? {
        var cgWindowId = CGWindowID()
        return _AXUIElementGetWindow(self, &cgWindowId) == .success ? cgWindowId : nil
    }
}
