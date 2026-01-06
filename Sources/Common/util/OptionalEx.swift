extension Optional {
    public func orDie(
        _ message: String = "",
        file: String = #fileID,
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

    public func flatMapAsync<U>(_ transform: (Wrapped) async throws -> U?) async rethrows -> U? {
        if let ok = self {
            return try await transform(ok)
        } else {
            return nil
        }
    }

    public func asList() -> [Wrapped] {
        if let ok = self {
            return [ok]
        } else {
            return []
        }
    }

    public var prettyDescription: String {
        if let unwrapped = self {
            return String(describing: unwrapped)
        }
        return "nil"
    }
}
