protocol ScopeFunctions {}

extension ScopeFunctions {
    @discardableResult
    func apply(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }

    @discardableResult
    func also(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }
}

extension TreeNode: ScopeFunctions {}
extension Writer: ScopeFunctions {}
