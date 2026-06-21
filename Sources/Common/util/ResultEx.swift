// periphery:ignore:all
extension Result {
    public init(catching body: () async throws(Failure) -> Success) async {
        do {
            self = .success(try await body())
        } catch {
            self = .failure(error)
        }
    }

    public func getOrNil(appendErrorTo errors: inout [Failure]) -> Success? {
        switch self {
            case .success(let success):
                return success
            case .failure(let error):
                errors.append(error)
                return nil
        }
    }

    public func filter(_ failure: @autoclosure () -> Failure, _ predicate: (Success) -> Bool) -> Self {
        flatMap { succ in predicate(succ) ? .success(succ) : .failure(failure()) }
    }

    public func getIgnoringErrorsOrNil() -> Success? {
        return switch self {
            case .success(let success): success
            case .failure: nil
        }
    }

    public func getOrNil(onFailure handle: (Failure) -> ()) -> Success? {
        switch self {
            case .success(let it): return it
            case .failure(let err):
                handle(err)
                return nil
        }
    }

    public func getOrNil(onFailure handle: (Failure) async -> ()) async -> Success? {
        switch self {
            case .success(let it): return it
            case .failure(let err):
                await handle(err)
                return nil
        }
    }

    public func get(or handle: (Failure) async -> Success) async -> Success {
        switch self {
            case .success(let it): return it
            case .failure(let err): return await handle(err)
        }
    }

    public var failureOrNil: Failure? {
        return switch self {
            case .success: nil
            case .failure(let f): f
        }
    }

    public var isSuccess: Bool {
        switch self {
            case .success: true
            case .failure: false
        }
    }
}

extension Result {
    @discardableResult
    public func getOrDie(
        _ msgPrefix: String = "",
        file: StaticString = #fileID,
        line: Int = #line,
        column: Int = #column,
        function: String = #function,
    ) -> Success {
        switch self {
            case .success(let suc):
                return suc
            case .failure(let e):
                die(msgPrefix + e.localizedDescription, file: file, line: line, column: column, function: function)
        }
    }
}
