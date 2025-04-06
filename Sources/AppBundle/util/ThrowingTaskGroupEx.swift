extension ThrowingTaskGroup {
    mutating func addTaskOrCancelAll(priority: TaskPriority? = nil, operation: sending @escaping @isolated(any) () async throws -> ChildTaskResult) throws {
        let succ = addTaskUnlessCancelled(priority: priority, operation: operation)
        if !succ {
            cancelAll()
            throw CancellationError()
        }
    }
}
