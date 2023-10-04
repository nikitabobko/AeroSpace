struct Writer<T, L> { // Writer monad
    let value: T
    let log: [L]
}

extension Writer {
    func flatMap<R>(_ transform: (T) -> Writer<R, L>) -> Writer<R, L> {
        let newWriter = transform(value)
        return Writer<R, L>(value: newWriter.value, log: log + newWriter.log)
    }

    func tell(_ item: L) -> Writer<T, L> { Writer(value: value, log: log + [item]) }
    func tell(_ items: [L]) -> Writer<T, L> { Writer(value: value, log: log + items) }

    func prependLogAndUnwrap(_ existingLog: [L]) -> (T, [L]) { (value, existingLog + log) }

    func map<R>(_ transform: (T) -> R) -> Writer<R, L> {
        flatMap { Writer<R, L>(value: transform($0), log: []) }
    }

    func toTuple() -> (T, [L]) { (value, log) }
}
