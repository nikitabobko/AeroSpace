import Foundation
import AppKit

// Alternative:
// @_silgen_name("_AXUIElementGetWindow")
// @discardableResult
// func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ id: inout CGWindowID) -> AXError
public protocol BridgedHeader {
    func containingWindowId(_ ax: AXUIElement) -> CGWindowID?
}

public var _bridgedHeader: BridgedHeader? = nil
public var bridgedHeader: BridgedHeader { _bridgedHeader! }
