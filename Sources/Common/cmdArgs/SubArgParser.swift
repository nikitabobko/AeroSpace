typealias SubArgParser<T: ConvenienceCopyable, K> = ArgParser<SubArgParserInput, T, K>

public struct SubArgParserInput: ArgParserInputProtocol, ConvenienceCopyable {
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
    ArgParser(\T.windowId, upcastArgParserFun(parseUInt32SubArg))
}
func optionalWorkspaceFlag<T: CmdArgs>() -> SubArgParser<T, WorkspaceName?> {
    ArgParser(\T.workspaceName, upcastArgParserFun(parseWorkspaceNameSubArg))
}

func trueBoolFlag<T: ConvenienceCopyable>(_ keyPath: SendableWritableKeyPath<T, Bool>) -> SubArgParser<T, Bool> {
    ArgParser(keyPath) { _ in .succ(true, advanceBy: 0) }
}

func falseBoolFlag<T: ConvenienceCopyable>(_ keyPath: SendableWritableKeyPath<T, Bool>) -> SubArgParser<T, Bool> {
    ArgParser(keyPath) { _ in .succ(false, advanceBy: 0) }
}

func boolFlag<T: ConvenienceCopyable>(_ keyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    ArgParser(keyPath) { input in input.argOrNil == "no" ? .succ(false, advanceBy: 1) : .succ(true, advanceBy: 0) }
}

func singleValueSubArgParser<T: ConvenienceCopyable, V>(
    _ keyPath: SendableWritableKeyPath<T, V?>,
    _ placeholder: String,
    _ mapper: @escaping @Sendable (String) -> V?,
) -> SubArgParser<T, V?> {
    ArgParser(keyPath) { input in
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
    ArgParser(keyPath) { _ in .succ(true, advanceBy: 0) }
}

func optionalFalseBoolFlag<T: ConvenienceCopyable>(_ KeyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    ArgParser(KeyPath) { _ in .succ(false, advanceBy: 0) }
}

func parseWorkspaceNameSubArg(i: SubArgParserInput) -> ParsedCliArgs<WorkspaceName> {
    if let arg = i.nonFlagArgOrNil() {
        .init(WorkspaceName.parse(arg), advanceBy: 1)
    } else {
        .fail("'\(i.superArg)' must be followed by mandatory workspace name", advanceBy: 0)
    }
}
