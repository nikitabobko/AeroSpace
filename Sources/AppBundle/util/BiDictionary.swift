struct BiDictionary<Key: Hashable, Value: Hashable> {
    private(set) var forward: [Key: Value] = [:]
    private(set) var backward: [Value: Key] = [:]

    mutating func put(_ key: Key, _ value: Value) {
        if let oldValue = forward[key] { backward[oldValue] = nil }
        if let oldKey = backward[value] { forward[oldKey] = nil }
        forward[key] = value
        backward[value] = key
    }
}
