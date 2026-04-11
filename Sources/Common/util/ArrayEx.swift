extension Array {
    public func transposed<T>() -> [[T]] where Self.Element == [T] {
        if isEmpty {
            return []
        }
        let table: [[T]] = self
        var result: [[T]] = []
        loop: for columnIndex in 0... {
            switch columnIndex < table.first.orDie().count {
                case true: result += [table.map { row in row.getOrNil(atIndex: columnIndex).orDie() }]
                case false: break loop
            }
        }
        return result
    }

    public func singleOrNil(where predicate: (Self.Element) throws -> Bool) rethrows -> Self.Element? {
        var found: Self.Element? = nil
        for elem in self where try predicate(elem) {
            switch found == nil {
                case true: found = elem
                case false: return nil
            }
        }
        return found
    }

    @discardableResult
    public mutating func remove(element: Self.Element) -> Int? where Self.Element: Equatable {
        switch firstIndex(of: element) {
            case nil: return nil
            case let index?:
                remove(at: index)
                return index
        }
    }
}

public func - <T>(lhs: [T], rhs: [T]) -> [T] where T: Hashable {
    let r = rhs.toSet()
    return lhs.filter { !r.contains($0) }
}
