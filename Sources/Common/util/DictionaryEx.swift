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
}
