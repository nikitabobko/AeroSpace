public typealias SendableWritableKeyPath<Root, Value> = Sendable & WritableKeyPath<Root, Value>
typealias ArgParserFun<Input, Value> = @Sendable (Input) -> ParsedCliArgs<Value>
protocol ArgParserProtocol<Input, Root, Context>: Sendable {
    associatedtype Input
    associatedtype Value
    associatedtype Root
    associatedtype Context
    var context: Context { get }
    var keyPath: SendableWritableKeyPath<Root, Value> { get }
    var parse: ArgParserFun<Input, Value> { get }
}
struct ArgParser<Input, Root, Value, Context: Sendable>: ArgParserProtocol {
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
        _ parse: @escaping ArgParserFun<SubArgParserInput, Value>,
    ) where Context == (), Input == SubArgParserInput {
        self.init(keyPath, parse, context: ())
    }

    init(
        _ keyPath: SendableWritableKeyPath<Root, Value>,
        _ parse: @escaping ArgParserFun<PosArgParserInput, Value>,
        argPlaceholderIfMandatory: String? = nil,
    ) where Context == PosArgParserContext, Input == PosArgParserInput {
        self.init(keyPath, parse, context: PosArgParserContext(argPlaceholderIfMandatory: argPlaceholderIfMandatory))
    }
}

typealias PosArgParser<Root, Value> = ArgParser<PosArgParserInput, Root, Value, PosArgParserContext>

struct PosArgParserContext {
    let argPlaceholderIfMandatory: String?
}

func newMandatoryPosArgParser<Root, Value>(
    _ keyPath: SendableWritableKeyPath<Root, Lateinit<Value>>,
    _ parse: @escaping @Sendable (PosArgParserInput) -> ParsedCliArgs<Value>,
    placeholder: String,
) -> PosArgParser<Root, Lateinit<Value>> {
    let parseWrapper: @Sendable (PosArgParserInput) -> ParsedCliArgs<Lateinit<Value>> = {
        parse($0).map { .initialized($0) }
    }
    return ArgParser(
        keyPath,
        parseWrapper,
        context: PosArgParserContext(argPlaceholderIfMandatory: placeholder),
    )
}

// todo reuse in config
public func parseEnum<T: RawRepresentable>(_ raw: String, _ _: T.Type) -> Parsed<T> where T.RawValue == String, T: CaseIterable {
    T(rawValue: raw).orFailure("Can't parse '\(raw)'.\nPossible values: \(T.unionLiteral)")
}

public func parseUInt32(_ str: String) -> Parsed<UInt32> { UInt32(str).orFailure("Can't convert '\(str)' to UInt32") }

func parseCardinalDirectionArg(i: PosArgParserInput) -> ParsedCliArgs<CardinalDirection> {
    .init(parseEnum(i.arg, CardinalDirection.self), advanceBy: 1)
}

func parseCardinalOrDfsDirection(i: PosArgParserInput) -> ParsedCliArgs<CardinalOrDfsDirection> {
    .init(parseEnum(i.arg, CardinalOrDfsDirection.self), advanceBy: 1)
}

func upcastArgParserFun<Input, T>(_ fun: @escaping ArgParserFun<Input, T>) -> ArgParserFun<Input, T?> {
    { fun($0).map(Optional.init) }
}
