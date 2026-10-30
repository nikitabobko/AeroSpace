import BasicContainers

extension UniqueDictionary where Value: ~Copyable {
    public var copiedOutKeys: [Key] {
        // non Copyable types boilerplate...
        var keys: [Key] = []
        keys.reserveCapacity(self.count)
        var i = self.startIndex
        while i != self.endIndex {
            keys.append(self[i].key)
            i = self.index(after: i)
        }
        return keys
    }
}
