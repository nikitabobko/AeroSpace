public extension Result {
    func getOrNil(appendErrorTo errors: inout [Failure]) -> Success? {
        switch self {
            case .success(let success):
                return success
            case .failure(let error):
                errors += [error]
                return nil
        }
    }

    func filter(_ failure: @autoclosure () -> Failure, _ predicate: (Success) -> Bool) -> Self {
        flatMap { succ in predicate(succ) ? .success(succ) : .failure(failure()) }
    }

    func getOrNil() -> Success? {
        switch self {
            case .success(let success):
                return success
            case .failure:
                return nil
        }
    }

    func getOrNils() -> (Success?, Failure?) {
        switch self {
            case .success(let success):
                return (success, nil)
            case .failure(let failure):
                return (nil, failure)
        }
    }

    var errorOrNil: Failure? {
        switch self {
            case .success:
                return nil
            case .failure(let f):
                return f
        }
    }
}

public extension Result {
    @discardableResult
    func getOrThrow(
        _ msgPrefix: String = "",
        file: String = #file,
        line: Int = #line,
        column: Int = #column,
        function: String = #function
    ) -> Success {
        switch self {
            case .success(let suc):
                return suc
            case .failure(let e):
                error(msgPrefix + e.localizedDescription, file: file, line: line, column: column, function: function)
        }
    }
}
