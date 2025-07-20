import Foundation
import AppKit

public protocol AeroAny {}

extension AeroAny {
    @discardableResult
    @inlinable
    public func apply(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }

    @discardableResult
    @inlinable
    public func also(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }

    @inlinable public func takeIf(_ predicate: (Self) -> Bool) -> Self? { predicate(self) ? self : nil }
    @inlinable public func then<R>(_ body: (Self) -> R) -> R { body(self) }
}

extension Int: AeroAny {}
extension String: AeroAny {}
extension Character: AeroAny {}
extension Regex: AeroAny {}
extension Array: AeroAny {}
extension URL: AeroAny {}
extension CGFloat: AeroAny {}
extension AXUIElement: AeroAny {}
extension CGPoint: AeroAny {}
