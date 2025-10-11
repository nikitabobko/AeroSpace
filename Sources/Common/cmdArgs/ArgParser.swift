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
        argPlaceholderIfMandatory: String? = nil
    ) {
        self.keyPath = keyPath
        self.parse = parse
        self.argPlaceholderIfMandatory = argPlaceholderIfMandatory
    }
}

public func optionalWindowIdFlag<T: CmdArgs>() -> SubArgParser<T, UInt32?> {
    SubArgParser(\T.windowId, upcastSubArgParserFun(parseArgWithUInt32))
}
public func optionalWorkspaceFlag<T: CmdArgs>() -> SubArgParser<T, WorkspaceName?> {
    SubArgParser(\T.workspaceName, upcastSubArgParserFun(parseArgWithWorkspaceName))
}

public struct ArgParserInput {
    let index: Int
    let args: StrArrSlice

    var arg: String { args[index] }
    func getOrNil(relativeIndex i: Int) -> String? { args.getOrNil(atIndex: index + i) }

    func nonFlagArgs() -> ArrSlice<String> {
        var i = index
        while args.indices.contains(i) && !args[i].starts(with: "-") {
            i += 1
        }
        return args.slice(index ..< i).orDie()
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
    mandatoryArgPlaceholder: String
) -> ArgParser<T, Lateinit<K>> {
    let parseWrapper: @Sendable (ArgParserInput) -> ParsedCliArgs<Lateinit<K>> = {
        parse($0).map { .initialized($0) }
    }
    return ArgParser(keyPath, parseWrapper, argPlaceholderIfMandatory: mandatoryArgPlaceholder)
}

public func trueBoolFlag<T: ConvenienceCopyable>(_ keyPath: SendableWritableKeyPath<T, Bool>) -> SubArgParser<T, Bool> {
    SubArgParser(keyPath) { _, _ in .success(true) }
}

public func falseBoolFlag<T: ConvenienceCopyable>(_ keyPath: SendableWritableKeyPath<T, Bool>) -> SubArgParser<T, Bool> {
    SubArgParser(keyPath) { _, _ in .success(false) }
}

public func boolFlag<T: ConvenienceCopyable>(_ keyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    SubArgParser(keyPath) { _, nextArgs in
        let value: Bool
        if let nextArg = nextArgs.first, nextArg == "no" {
            _ = nextArgs.next() // Consume the argument
            value = false
        } else {
            value = true
        }
        return .success(value)
    }
}

public func singleValueOption<T: ConvenienceCopyable, V>(
    _ keyPath: SendableWritableKeyPath<T, V?>,
    _ placeholder: String,
    _ mapper: @escaping @Sendable (String) -> V?
) -> SubArgParser<T, V?> {
    SubArgParser(keyPath) { arg, nextArgs in
        if let arg = nextArgs.nextNonFlagOrNil() {
            if let value: V = mapper(arg) {
                return .success(value)
            } else {
                return .failure("Failed to convert '\(arg)' to '\(V.self)'")
            }
        } else {
            return .failure("'\(placeholder)' is mandatory")
        }
    }
}

public func optionalTrueBoolFlag<T: ConvenienceCopyable>(_ keyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    SubArgParser(keyPath) { _, _ in .success(true) }
}

public func optionalFalseBoolFlag<T: ConvenienceCopyable>(_ KeyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    SubArgParser(KeyPath) { _, _ in .success(false) }
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

public func parseArgWithUInt32(arg: String, nextArgs: inout [String]) -> Parsed<UInt32> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return UInt32(arg).orFailure("Can't parse '\(arg)'. It must be a positive number")
    } else {
        return .failure("'\(arg)' must be followed by mandatory UInt32")
    }
}

public func parseArgWithWorkspaceName(arg: String, nextArgs: inout [String]) -> Parsed<WorkspaceName> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        WorkspaceName.parse(arg)
    } else {
        .failure("'\(arg)' must be followed by mandatory workspace name")
    }
}

func upcastArgParserFun<T>(_ fun: @escaping ArgParserFun<T>) -> ArgParserFun<T?> { { fun($0).map { $0 } } }
