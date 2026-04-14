public struct ParsedCliArgs<T> {
    var value: Parsed<T>
    var advanceBy: Int

    public init(_ value: Parsed<T>, advanceBy: Int) {
        self.value = value
        self.advanceBy = advanceBy
    }

    public static func succ(_ value: T, advanceBy: Int) -> ParsedCliArgs<T> {
        .init(.success(value), advanceBy: advanceBy)
    }

    public static func fail(_ msg: String, advanceBy: Int) -> ParsedCliArgs<T> {
        .init(.failure(msg), advanceBy: advanceBy)
    }

    public func flatMap<R>(_ mapper: (T) -> ParsedCliArgs<R>) -> ParsedCliArgs<R> {
        switch value {
            case .failure(let msg): ParsedCliArgs<R>(.failure(msg), advanceBy: advanceBy)
            case .success(let value): mapper(value)
        }
    }

    public func map<R>(_ mapper: (T) -> R) -> ParsedCliArgs<R> {
        flatMap { ParsedCliArgs<R>(.success(mapper($0)), advanceBy: advanceBy) }
    }
}
