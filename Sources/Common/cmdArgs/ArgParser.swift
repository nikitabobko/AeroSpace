public typealias SendableWritableKeyPath<A, B> = Sendable & WritableKeyPath<A, B>
public typealias ArgParserFun<K> = @Sendable (ArgParserInput) -> ParsedCliArgs<K>
public protocol ArgParserProtocol<T>: Sendable {
    associatedtype K
    associatedtype T where T: ConvenienceCopyable
    var argPlaceholderIfMandatory: String? { get }
    var keyPath: SendableWritableKeyPath<T, K> { get }
    var parse: ArgParserFun<K> { get }
}
public struct ArgParser<T: ConvenienceCopyable, K>: ArgParserProtocol {
    public let keyPath: SendableWritableKeyPath<T, K>
    public let parse: ArgParserFun<K>
    public let argPlaceholderIfMandatory: String?

    public init(
        _ keyPath: SendableWritableKeyPath<T, K>,
        _ parse: @escaping ArgParserFun<K>,
        argPlaceholderIfMandatory: String? = nil,
    ) {
        self.keyPath = keyPath
        self.parse = parse
        self.argPlaceholderIfMandatory = argPlaceholderIfMandatory
    }
}

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

func newArgParser<T: ConvenienceCopyable, K>(
    _ keyPath: SendableWritableKeyPath<T, Lateinit<K>> & Sendable,
    _ parse: @escaping @Sendable (ArgParserInput) -> ParsedCliArgs<K>,
    mandatoryArgPlaceholder: String,
) -> ArgParser<T, Lateinit<K>> {
    let parseWrapper: @Sendable (ArgParserInput) -> ParsedCliArgs<Lateinit<K>> = {
        parse($0).map { .initialized($0) }
    }
    return ArgParser(keyPath, parseWrapper, argPlaceholderIfMandatory: mandatoryArgPlaceholder)
}

// todo reuse in config
public func parseEnum<T: RawRepresentable>(_ raw: String, _ _: T.Type) -> Parsed<T> where T.RawValue == String, T: CaseIterable {
    T(rawValue: raw).orFailure("Can't parse '\(raw)'.\nPossible values: \(T.unionLiteral)")
}

public func parseCardinalDirectionArg(i: ArgParserInput) -> ParsedCliArgs<CardinalDirection> {
    .init(parseEnum(i.arg, CardinalDirection.self), advanceBy: 1)
}

func parseCardinalOrDfsDirection(i: ArgParserInput) -> ParsedCliArgs<CardinalOrDfsDirection> {
    .init(parseEnum(i.arg, CardinalOrDfsDirection.self), advanceBy: 1)
}

func upcastArgParserFun<T>(_ fun: @escaping ArgParserFun<T>) -> ArgParserFun<T?> { { fun($0).map { $0 } } }
