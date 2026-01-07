public typealias SendableWritableKeyPath<Root, Value> = Sendable & WritableKeyPath<Root, Value>
typealias ArgParserFun<Input, Value> = @Sendable (Input) -> ParsedCliArgs<Value>
protocol ArgParserProtocol<Input, Root, Context>: Sendable {
    associatedtype Input
    associatedtype Value
    associatedtype Root: ConvenienceCopyable
    associatedtype Context
    var context: Context { get }
    var keyPath: SendableWritableKeyPath<Root, Value> { get }
    var parse: ArgParserFun<Input, Value> { get }
}
struct ArgParser<Input, Root: ConvenienceCopyable, Value, Context: Sendable>: ArgParserProtocol {
    let keyPath: SendableWritableKeyPath<Root, Value>
    let parse: ArgParserFun<Input, Value>
    let context: Context

    init(
        _ keyPath: SendableWritableKeyPath<Root, Value>,
        _ parse: @escaping ArgParserFun<Input, Value>,
        context: Context,
    ) {
        self.keyPath = keyPath
        self.parse = parse
        self.context = context
    }

    init(
        _ keyPath: SendableWritableKeyPath<Root, Value>,
        _ parse: @escaping ArgParserFun<Input, Value>,
    ) where Context == () {
        self.init(keyPath, parse, context: ())
    }

    init(
        _ keyPath: SendableWritableKeyPath<Root, Value>,
        _ parse: @escaping ArgParserFun<Input, Value>,
        argPlaceholderIfMandatory: String? = nil,
    ) where Context == PosArgParserContext {
        self.init(keyPath, parse, context: PosArgParserContext(argPlaceholderIfMandatory: argPlaceholderIfMandatory))
    }
}

typealias PosArgParser<Root: ConvenienceCopyable, Value> = ArgParser<PosArgParserInput, Root, Value, PosArgParserContext>

struct PosArgParserContext {
    let argPlaceholderIfMandatory: String?
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

func newMandatoryPosArgParser<Root: ConvenienceCopyable, Value>(
    _ keyPath: SendableWritableKeyPath<Root, Lateinit<Value>> & Sendable,
    _ parse: @escaping @Sendable (PosArgParserInput) -> ParsedCliArgs<Value>,
    placeholder: String,
) -> PosArgParser<Root, Lateinit<Value>> {
    let parseWrapper: @Sendable (PosArgParserInput) -> ParsedCliArgs<Lateinit<Value>> = {
        parse($0).map { .initialized($0) }
    }
    return PosArgParser(
        keyPath,
        parseWrapper,
        context: PosArgParserContext(argPlaceholderIfMandatory: placeholder),
    )
}

// todo reuse in config
public func parseEnum<T: RawRepresentable>(_ raw: String, _ _: T.Type) -> Parsed<T> where T.RawValue == String, T: CaseIterable {
    T(rawValue: raw).orFailure("Can't parse '\(raw)'.\nPossible values: \(T.unionLiteral)")
}

func parseCardinalDirectionArg(i: PosArgParserInput) -> ParsedCliArgs<CardinalDirection> {
    .init(parseEnum(i.arg, CardinalDirection.self), advanceBy: 1)
}

func parseCardinalOrDfsDirection(i: PosArgParserInput) -> ParsedCliArgs<CardinalOrDfsDirection> {
    .init(parseEnum(i.arg, CardinalOrDfsDirection.self), advanceBy: 1)
}

func upcastArgParserFun<Input, T>(_ fun: @escaping ArgParserFun<Input, T>) -> ArgParserFun<Input, T?> { { fun($0).map { $0 } } }
