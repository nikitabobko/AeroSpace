import Foundation
import AppKit

public protocol BridgedHeader {
    func containingWindowId(_ ax: AXUIElement) -> CGWindowID?
}

public var _bridgedHeader: BridgedHeader? = nil
public var bridgedHeader: BridgedHeader { _bridgedHeader! }
