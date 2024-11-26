public extension Set {
    internal func toArray() -> [Element] { Array(self) }

    @inlinable static func += (lhs: inout Set<Element>, rhs: any Sequence<Element>) {
        lhs.formUnion(rhs)
    }

    @inlinable static func -= (lhs: inout Set<Element>, rhs: any Sequence<Element>) {
        lhs.subtract(rhs)
    }
}
