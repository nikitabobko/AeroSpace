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
        self.map(Result.success) ?? .failure(or())
    }

    public func asList() -> [Wrapped] {
        switch self {
            case let ok?: [ok]
            case nil: []
        }
    }

    public func flattenOptional<T>() -> T? where Wrapped == T? {
        switch self {
            case let x?: x
            case nil: nil
        }
    }

    public var prettyDescription: String {
        switch self {
            case let ok?: String(describing: ok)
            case nil: "nil"
        }
    }
}
