extension Collection {
    public func singleOrNil() -> Element? {
        count == 1 ? first : nil
    }

    public func getOrNil(atIndex index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Collection where Index == Int {
    public func get(wrappingIndex: Int) -> Element? { isEmpty ? nil : self[((wrappingIndex % count) + count) % count] }
}
