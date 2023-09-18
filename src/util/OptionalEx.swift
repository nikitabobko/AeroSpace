extension Optional {
    func orElse(_ other: () -> Wrapped) -> Wrapped { self ?? other() }
}
