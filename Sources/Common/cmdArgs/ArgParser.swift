public typealias SendableWritableKeyPath<A, B> = Sendable & WritableKeyPath<A, B>
public typealias ArgParserFun<Input, K> = @Sendable (Input) -> ParsedCliArgs<K>
public protocol ArgParserProtocol<Input, T>: Sendable {
    associatedtype Input
    associatedtype K
    associatedtype T where T: ConvenienceCopyable
    var argPlaceholderIfMandatory: String? { get }
    var keyPath: SendableWritableKeyPath<T, K> { get }
    var parse: ArgParserFun<Input, K> { get }
}
struct ArgParser<Input, T: ConvenienceCopyable, K>: ArgParserProtocol {
    let keyPath: SendableWritableKeyPath<T, K>
    let parse: ArgParserFun<Input, K>
    let argPlaceholderIfMandatory: String?

    init(
        _ keyPath: SendableWritableKeyPath<T, K>,
        _ parse: @escaping ArgParserFun<Input, K>,
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
) -> ArgParser<ArgParserInput, T, Lateinit<K>> {
    let parseWrapper: @Sendable (ArgParserInput) -> ParsedCliArgs<Lateinit<K>> = {
        parse($0).map { .initialized($0) }
    }
    return ArgParser(keyPath, parseWrapper, argPlaceholderIfMandatory: mandatoryArgPlaceholder)
}

// todo reuse in config
public func parseEnum<T: RawRepresentable>(_ raw: String, _ _: T.Type) -> Parsed<T> where T.RawValue == String, T: CaseIterable {
    T(rawValue: raw).orFailure("Can't parse '\(raw)'.\nPossible values: \(T.unionLiteral)")
}

func parseCardinalDirectionArg(i: ArgParserInput) -> ParsedCliArgs<CardinalDirection> {
    .init(parseEnum(i.arg, CardinalDirection.self), advanceBy: 1)
}

func parseCardinalOrDfsDirection(i: ArgParserInput) -> ParsedCliArgs<CardinalOrDfsDirection> {
    .init(parseEnum(i.arg, CardinalOrDfsDirection.self), advanceBy: 1)
}

func upcastArgParserFun<Input, T>(_ fun: @escaping ArgParserFun<Input, T>) -> ArgParserFun<Input, T?> { { fun($0).map { $0 } } }
