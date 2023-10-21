extension Collection {
    func singleOrNil() -> Element? {
        count == 1 ? first : nil
    }

    func getOrNil(atIndex index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Collection where Index == Int {
    func get(wrappingIndex: Int) -> Element { self[(count + wrappingIndex) % count] }
}
