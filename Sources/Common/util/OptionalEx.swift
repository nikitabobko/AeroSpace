public extension Optional {
    func orElse(_ other: () -> Wrapped) -> Wrapped { self ?? other() }

    func orFailure<F: Error>(_ or: @autoclosure () -> F) -> Result<Wrapped, F> {
        if let ok = self {
            return .success(ok)
        } else {
            return .failure(or())
        }
    }

    func mapAsync<E, U>(_ transform: (Wrapped) async throws(E) -> U) async throws(E) -> U? where E: Error, U: ~Copyable {
        if let ok = self {
            return try await transform(ok)
        } else {
            return nil
        }
    }

    // todo cleanup in future Swift versions
    @MainActor
    func mapAsyncMainActor<E, U>(_ transform: @MainActor (Wrapped) async throws(E) -> U) async throws(E) -> U? where E: Error, U: ~Copyable {
        if let ok = self {
            return try await transform(ok)
        } else {
            return nil
        }
    }

    func flatMapAsync<E, U>(_ transform: (Wrapped) async throws(E) -> U?) async throws(E) -> U? where E: Error, U: ~Copyable {
        if let ok = self {
            return try await transform(ok)
        } else {
            return nil
        }
    }

    // todo cleanup in future Swift versions
    @MainActor
    func flatMapAsyncMainActor<E, U>(_ transform: @MainActor (Wrapped) async throws(E) -> U?) async throws(E) -> U? where E: Error, U: ~Copyable {
        if let ok = self {
            return try await transform(ok)
        } else {
            return nil
        }
    }

    func asList() -> [Wrapped] {
        if let ok = self {
            return [ok]
        } else {
            return []
        }
    }

    var prettyDescription: String {
        if let unwrapped = self {
            return String(describing: unwrapped)
        }
        return "nil"
    }
}
