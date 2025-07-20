extension Result {
    public func getOrNil(appendErrorTo errors: inout [Failure]) -> Success? {
        switch self {
            case .success(let success):
                return success
            case .failure(let error):
                errors += [error]
                return nil
        }
    }

    public func filter(_ failure: @autoclosure () -> Failure, _ predicate: (Success) -> Bool) -> Self {
        flatMap { succ in predicate(succ) ? .success(succ) : .failure(failure()) }
    }

    public func getOrNil() -> Success? {
        return switch self {
            case .success(let success): success
            case .failure: nil
        }
    }

    public func getOrNils() -> (Success?, Failure?) {
        return switch self {
            case .success(let success): (success, nil)
            case .failure(let failure): (nil, failure)
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
        file: String = #fileID,
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
