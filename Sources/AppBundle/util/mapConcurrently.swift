import Common

/// Order preserving. Useful to overlap AX requests to different apps, since each app has its own AX thread
@MainActor
func mapConcurrently<T: AnyObject, R: Sendable>(
    _ items: [T],
    _ transform: @escaping @Sendable @MainActor (T) async throws -> R,
) async throws -> [R] {
    try await withThrowingTaskGroup(of: (Int, R).self) { group in
        for (index, item) in items.enumerated() {
            let ref = MainActorRef(item)
            group.addTask { @Sendable @MainActor in (index, try await transform(ref.value)) }
        }
        var result: [R?] = Array(repeating: nil, count: items.count)
        for try await (index, value) in group {
            result[index] = value
        }
        return result.map { $0.orDie() }
    }
}
