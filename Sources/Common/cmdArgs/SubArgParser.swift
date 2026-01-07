public typealias SubArgParserFun<K> = @Sendable (SubArgParserInput) -> ParsedCliArgs<K>
public protocol SubArgParserProtocol<T>: Sendable, AeroAny {
    associatedtype K
    associatedtype T where T: ConvenienceCopyable
    var keyPath: SendableWritableKeyPath<T, K> { get }
    var parse: SubArgParserFun<K> { get }
}
struct SubArgParser<T: ConvenienceCopyable, K>: SubArgParserProtocol {
    let keyPath: SendableWritableKeyPath<T, K>
    let parse: SubArgParserFun<K>

    init(
        _ keyPath: SendableWritableKeyPath<T, K>,
        _ parse: @escaping SubArgParserFun<K>,
    ) {
        self.keyPath = keyPath
        self.parse = parse
    }
}

func upcastSubArgParserFun<T>(_ fun: @escaping SubArgParserFun<T>) -> SubArgParserFun<T?> { { fun($0).map { $0 } } }

public struct SubArgParserInput: ArgParserInputProtocol {
    let superArg: String
    /*conforms*/ let index: Int
    /*conforms*/ let args: StrArrSlice

    var argOrNil: String? { args.getOrNil(atIndex: index) }
}

func parseUInt32SubArg(i: SubArgParserInput) -> ParsedCliArgs<UInt32> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(UInt32(arg).orFailure("Can't parse '\(arg)'. It must be a positive number"), advanceBy: 1)
    } else {
        return .fail("'\(i.superArg)' must be followed by mandatory UInt32", advanceBy: 0)
    }
}

func optionalWindowIdFlag<T: CmdArgs>() -> SubArgParser<T, UInt32?> {
    SubArgParser(\T.windowId, upcastSubArgParserFun(parseUInt32SubArg))
}
func optionalWorkspaceFlag<T: CmdArgs>() -> SubArgParser<T, WorkspaceName?> {
    SubArgParser(\T.workspaceName, upcastSubArgParserFun(parseWorkspaceNameSubArg))
}

func trueBoolFlag<T: ConvenienceCopyable>(_ keyPath: SendableWritableKeyPath<T, Bool>) -> SubArgParser<T, Bool> {
    SubArgParser(keyPath) { _ in .succ(true, advanceBy: 0) }
}

func falseBoolFlag<T: ConvenienceCopyable>(_ keyPath: SendableWritableKeyPath<T, Bool>) -> SubArgParser<T, Bool> {
    SubArgParser(keyPath) { _ in .succ(false, advanceBy: 0) }
}

func boolFlag<T: ConvenienceCopyable>(_ keyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    SubArgParser(keyPath) { input in input.argOrNil == "no" ? .succ(false, advanceBy: 1) : .succ(true, advanceBy: 0) }
}

func singleValueSubArgParser<T: ConvenienceCopyable, V>(
    _ keyPath: SendableWritableKeyPath<T, V?>,
    _ placeholder: String,
    _ mapper: @escaping @Sendable (String) -> V?,
) -> SubArgParser<T, V?> {
    SubArgParser(keyPath) { input in
        if let arg = input.nonFlagArgOrNil() {
            if let value: V = mapper(arg) {
                .succ(value, advanceBy: 1)
            } else {
                .fail("Failed to convert '\(arg)' to '\(V.self)'", advanceBy: 1)
            }
        } else {
            .fail("'\(placeholder)' is mandatory", advanceBy: 0)
        }
    }
}

func optionalTrueBoolFlag<T: ConvenienceCopyable>(_ keyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    SubArgParser(keyPath) { _ in .succ(true, advanceBy: 0) }
}

func optionalFalseBoolFlag<T: ConvenienceCopyable>(_ KeyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    SubArgParser(KeyPath) { _ in .succ(false, advanceBy: 0) }
}

func parseWorkspaceNameSubArg(i: SubArgParserInput) -> ParsedCliArgs<WorkspaceName> {
    if let arg = i.nonFlagArgOrNil() {
        .init(WorkspaceName.parse(arg), advanceBy: 1)
    } else {
        .fail("'\(i.superArg)' must be followed by mandatory workspace name", advanceBy: 0)
    }
}
