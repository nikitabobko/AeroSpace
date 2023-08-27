extension Optional {
    func filterIsInstance<R>(of: R.Type) -> Optional<R> {
        if let value = self as? R {
            return value
        } else {
            return nil
        }
    }
}
