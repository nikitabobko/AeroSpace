typealias SubArgParser<Root, Value> = ArgParser<SubArgParserInput, Root, Value, ()>

func parseUInt32SubArg(i: SubArgParserInput) -> ParsedCliArgs<UInt32> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(UInt32(arg).orFailure("Can't parse '\(arg)'. It must be a positive number"), advanceBy: 1)
    } else {
        return .fail("'\(i.superArg)' must be followed by mandatory UInt32", advanceBy: 0)
    }
}

func optionalWindowIdFlag<T: CmdArgs>() -> SubArgParser<T, UInt32?> {
    SubArgParser(\T.windowId, upcastArgParserFun(parseUInt32SubArg))
}
func optionalWorkspaceFlag<T: CmdArgs>() -> SubArgParser<T, WorkspaceName?> {
    SubArgParser(\T.workspaceName, upcastArgParserFun(parseWorkspaceNameSubArg))
}

func trueBoolFlag<T>(_ keyPath: SendableWritableKeyPath<T, Bool>) -> SubArgParser<T, Bool> {
    SubArgParser(keyPath) { _ in .succ(true, advanceBy: 0) }
}

func falseBoolFlag<T>(_ keyPath: SendableWritableKeyPath<T, Bool>) -> SubArgParser<T, Bool> {
    SubArgParser(keyPath) { _ in .succ(false, advanceBy: 0) }
}

func boolFlag<T>(_ keyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    SubArgParser(keyPath) { input in input.argOrNil == "no" ? .succ(false, advanceBy: 1) : .succ(true, advanceBy: 0) }
}

func singleValueSubArgParser<Root, Value>(
    _ keyPath: SendableWritableKeyPath<Root, Value?>,
    _ placeholder: String,
    _ mapper: @escaping @Sendable (String) -> Value?,
) -> SubArgParser<Root, Value?> {
    SubArgParser(keyPath) { input in
        if let arg = input.nonFlagArgOrNil() {
            if let value: Value = mapper(arg) {
                .succ(value, advanceBy: 1)
            } else {
                .fail("Failed to convert '\(arg)' to '\(Value.self)'", advanceBy: 1)
            }
        } else {
            .fail("'\(placeholder)' is mandatory", advanceBy: 0)
        }
    }
}

func optionalTrueBoolFlag<T>(_ keyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    SubArgParser(keyPath) { _ in .succ(true, advanceBy: 0) }
}

func optionalFalseBoolFlag<T>(_ KeyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    SubArgParser(KeyPath) { _ in .succ(false, advanceBy: 0) }
}

func parseWorkspaceNameSubArg(i: SubArgParserInput) -> ParsedCliArgs<WorkspaceName> {
    if let arg = i.nonFlagArgOrNil() {
        .init(WorkspaceName.parse(arg), advanceBy: 1)
    } else {
        .fail("'\(i.superArg)' must be followed by mandatory workspace name", advanceBy: 0)
    }
}
