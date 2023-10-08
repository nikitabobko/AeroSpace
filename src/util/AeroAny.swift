protocol AeroAny {}

extension AeroAny {
    @discardableResult
    @inlinable
    func apply(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }

    @discardableResult
    @inlinable
    func also(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }

    @inlinable func takeIf(_ predicate: (Self) -> Bool) -> Self? { predicate(self) ? self : nil }
}

extension TreeNode: AeroAny {}
extension Writer: AeroAny {}
extension Int: AeroAny {}
extension CGFloat: AeroAny {}
