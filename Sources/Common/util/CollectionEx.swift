extension Collection {
    public func singleOrNil() -> Element? {
        count == 1 ? first : nil
    }

    public func getOrNil(atIndex index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }

    @MainActor public func mapConcurrently<R: Sendable>(
        _ transform: @escaping @Sendable @MainActor (Element) async throws -> R,
    ) async throws -> [R] {
        try await withThrowingTaskGroup(of: (Int, R).self) { group in
            for (index, item) in enumerated() {
                group.addTask { @Sendable @MainActor in (index, try await transform(item)) }
            }
            var result: [R?] = Array(repeating: nil, count: self.count)
            for try await (index, value) in group {
                result[index] = value
            }
            return result.map { $0.orDie() }
        }
    }
}

extension Collection where Index == Int {
    public func get(wrappingIndex: Int) -> Element? { isEmpty ? nil : self[((wrappingIndex % count) + count) % count] }
}
