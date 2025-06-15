extension Optional {
    public func orElse(_ other: () -> Wrapped) -> Wrapped { self ?? other() }

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

    public func mapAsync<E, U>(_ transform: (Wrapped) async throws(E) -> U) async throws(E) -> U? where E: Error, U: ~Copyable {
        if let ok = self {
            return try await transform(ok)
        } else {
            return nil
        }
    }

    // todo cleanup in future Swift versions
    @MainActor
    public func mapAsyncMainActor<E, U>(_ transform: @MainActor (Wrapped) async throws(E) -> U) async throws(E) -> U? where E: Error, U: ~Copyable {
        if let ok = self {
            return try await transform(ok)
        } else {
            return nil
        }
    }

    public func flatMapAsync<E, U>(_ transform: (Wrapped) async throws(E) -> U?) async throws(E) -> U? where E: Error, U: ~Copyable {
        if let ok = self {
            return try await transform(ok)
        } else {
            return nil
        }
    }

    // todo cleanup in future Swift versions
    @MainActor
    public func flatMapAsyncMainActor<E, U>(_ transform: @MainActor (Wrapped) async throws(E) -> U?) async throws(E) -> U? where E: Error, U: ~Copyable {
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
