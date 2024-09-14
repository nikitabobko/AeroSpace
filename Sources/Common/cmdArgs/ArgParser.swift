public typealias ArgParserFun<K> = (/*arg*/ String, /*nextArgs*/ inout [String]) -> Parsed<K>
public protocol ArgParserProtocol<T> {
    associatedtype K
    associatedtype T where T: Copyable
    var argPlaceholderIfMandatory: String? { get }
    var keyPath: WritableKeyPath<T, K> { get }
    var parse: ArgParserFun<K> { get }
}
public struct ArgParser<T: Copyable, K>: ArgParserProtocol {
    public let keyPath: WritableKeyPath<T, K>
    public let parse: ArgParserFun<K>
    public let argPlaceholderIfMandatory: String?

    public init(
        _ keyPath: WritableKeyPath<T, K>,
        _ parse: @escaping ArgParserFun<K>,
        argPlaceholderIfMandatory: String? = nil
    ) {
        self.keyPath = keyPath
        self.parse = parse
        self.argPlaceholderIfMandatory = argPlaceholderIfMandatory
    }

    public static func == (lhs: ArgParser<T, K>, rhs: ArgParser<T, K>) -> Bool { lhs.keyPath == rhs.keyPath }
    public func hash(into hasher: inout Hasher) { hasher.combine(keyPath) }
}

func newArgParser<T: Copyable, K>(
    _ keyPath: WritableKeyPath<T, Lateinit<K>>,
    _ parse: @escaping (String, inout [String]) -> Parsed<K>,
    mandatoryArgPlaceholder: String
) -> ArgParser<T, Lateinit<K>> {
    let parseWrapper: (String, inout [String]) -> Parsed<Lateinit<K>> = { arg, nextArgs in
        parse(arg, &nextArgs).map { .initialized($0) }
    }
    return ArgParser(keyPath, parseWrapper, argPlaceholderIfMandatory: mandatoryArgPlaceholder)
}

public func trueBoolFlag<T: Copyable>(_ keyPath: WritableKeyPath<T, Bool>) -> ArgParser<T, Bool> {
    ArgParser(keyPath) { _, _ in .success(true) }
}

public func falseBoolFlag<T: Copyable>(_ keyPath: WritableKeyPath<T, Bool>) -> ArgParser<T, Bool> {
    ArgParser(keyPath) { _, _ in .success(false) }
}

public func boolFlag<T: Copyable>(_ keyPath: WritableKeyPath<T, Bool?>) -> ArgParser<T, Bool?> {
    ArgParser(keyPath) { _, nextArgs in
        let value: Bool
        if let nextArg = nextArgs.first, nextArg == "no" {
            _ = nextArgs.next() // Eat the argument
            value = false
        } else {
            value = true
        }
        return .success(value)
    }
}

public func singleValueOption<T: Copyable, V>(
    _ keyPath: WritableKeyPath<T, V?>,
    _ placeholder: String,
    _ mapper: @escaping (String) -> V?
) -> ArgParser<T, V?> {
    ArgParser(keyPath) { arg, nextArgs in
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

public func optionalTrueBoolFlag<T: Copyable>(_ keyPath: WritableKeyPath<T, Bool?>) -> ArgParser<T, Bool?> {
    ArgParser(keyPath) { _, _ in .success(true) }
}

// todo reuse in config
public func parseEnum<T: RawRepresentable>(_ raw: String, _ _: T.Type) -> Parsed<T> where T.RawValue == String, T: CaseIterable {
    T(rawValue: raw).orFailure("Can't parse '\(raw)'.\nPossible values: \(T.unionLiteral)")
}

public func parseCardinalDirectionArg(arg: String, nextArgs: inout [String]) -> Parsed<CardinalDirection> {
    parseEnum(arg, CardinalDirection.self)
}

public func parseArgWithUInt32(arg: String, nextArgs: inout [String]) -> Parsed<UInt32> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return UInt32(arg).orFailure("Can't parse '\(arg)'. It must be a positive number")
    } else {
        return .failure("'\(arg)' must be followed by mandatory UInt32")
    }
}

func upcastArgParserFun<T>(_ fun: @escaping ArgParserFun<T>) -> ArgParserFun<T?> { { fun($0, &$1).map { $0 } } }
