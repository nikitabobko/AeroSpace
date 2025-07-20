import Common

extension Array {
    func singleOrNil(where predicate: (Self.Element) throws -> Bool) rethrows -> Self.Element? {
        var found: Self.Element? = nil
        for elem in self where try predicate(elem) {
            if found == nil {
                found = elem
            } else {
                return nil
            }
        }
        return found
    }
}

extension Array where Self.Element: Equatable {
    @discardableResult
    mutating func remove(element: Self.Element) -> Int? {
        if let index = firstIndex(of: element) {
            remove(at: index)
            return index
        } else {
            return nil
        }
    }
}

func - <T>(lhs: [T], rhs: [T]) -> [T] where T: Hashable {
    let r = rhs.toSet()
    return lhs.filter { !r.contains($0) }
}
