extension Optional {
    func orElse(_ other: () -> Wrapped) -> Wrapped { self ?? other() }

    func orFailure<F: Error>(_ or: () -> F) -> Result<Wrapped, F> {
        if let ok = self {
            return .success(ok)
        } else {
            return .failure(or())
        }
    }

    func orFailure<F: Error>(_ or: F) -> Result<Wrapped, F> { orFailure { or } }
}
