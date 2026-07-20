// periphery:ignore:all
extension Dictionary {
    @inlinable public func partition(_ predicate: (Dictionary<Key, Value>.Element) throws -> Bool) rethrows -> ([Key: Value], [Key: Value]) {
        var matching = [Key: Value]()
        var nonMatching = [Key: Value]()

        for element in self {
            if try predicate(element) {
                matching[element.key] = element.value
            } else {
                nonMatching[element.key] = element.value
            }
        }

        return (matching, nonMatching)
    }

    public var entries: [(key: Key, value: Value)] {
        var result: [(Key, Value)] = []
        for entry in self {
            result.append((entry.key, entry.value))
        }
        return result
    }
}

extension Dictionary where Key: Comparable {
    public var sortedEntries: [(key: Key, value: Value)] {
        entries.sortedBy { $0.key }
    }
}

public func + <K, V>(lhs: [K: V], rhs: [K: V]) -> [K: V] {
    lhs.merging(rhs) { _, r in r }
}
