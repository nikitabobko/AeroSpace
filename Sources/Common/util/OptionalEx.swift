extension Optional {
    public func orDie(
        _ message: String = "",
        file: StaticString = #fileID,
        line: Int = #line,
        column: Int = #column,
        function: String = #function,
    ) -> Wrapped {
        self ?? dieT("orDie: " + message, file: file, line: line, column: column, function: function)
    }

    public func orFailure<F: Error>(_ or: @autoclosure () -> F) -> Result<Wrapped, F> {
        if let ok = self {
            return .success(ok)
        } else {
            return .failure(or())
        }
    }

    public func asList() -> [Wrapped] {
        if let ok = self {
            return [ok]
        } else {
            return []
        }
    }

    public func flattenOptional<T>() -> T? where Wrapped == T? {
        switch self {
            case let x?: x
            case nil: nil
        }
    }

    public var prettyDescription: String {
        if let unwrapped = self {
            return String(describing: unwrapped)
        }
        return "nil"
    }
}
