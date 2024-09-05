public extension LazySequenceProtocol {
    func filterNotNil<Unwrapped>() -> LazyMapSequence<LazyFilterSequence<Self.Elements>.Elements, Unwrapped> where Element == Unwrapped? {
        filter { $0 != nil }.map { $0! }
    }
}
