extension Dictionary {
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
