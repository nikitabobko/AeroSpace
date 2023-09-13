extension Optional {
    func filterIsInstance<R>(of: R.Type) -> Optional<R> {
        self as? R ?? nil
    }
}
