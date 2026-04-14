typealias SubArgParser<Root, Value> = ArgParser<SubArgParserInput, Root, Value, ()>

func windowIdSubArgParser<T: CmdArgs>() -> SubArgParser<T, UInt32?> {
    singleValueSubArgParser(\T.windowId, "<window-id>", parseUInt32)
}
func workspaceSubArgParser<T: CmdArgs>() -> SubArgParser<T, WorkspaceName?> {
    singleValueSubArgParser(\T.workspaceName, "<workspace>", WorkspaceName.parse)
}

func trueBoolFlag<T>(_ keyPath: SendableWritableKeyPath<T, Bool>) -> SubArgParser<T, Bool> {
    ArgParser(keyPath, constSubArgParserFun(true))
}

func falseBoolFlag<T>(_ keyPath: SendableWritableKeyPath<T, Bool>) -> SubArgParser<T, Bool> {
    ArgParser(keyPath, constSubArgParserFun(false))
}

func boolFlag<T>(_ keyPath: SendableWritableKeyPath<T, Bool?>) -> SubArgParser<T, Bool?> {
    ArgParser(keyPath) { input in input.argOrNil == "no" ? .succ(false, advanceBy: 1) : .succ(true, advanceBy: 0) }
}

func singleValueSubArgParser<Root, Value>(
    _ keyPath: SendableWritableKeyPath<Root, Value?>,
    _ placeholder: String,
    _ mapper: @escaping @Sendable (String) -> Parsed<Value>,
) -> SubArgParser<Root, Value?> {
    ArgParser(keyPath) { input in
        switch input.nonFlagArgOrNil() {
            case nil: .fail("'\(input.superArg)' must be followed by '\(placeholder)'", advanceBy: 0)
            case let arg?:
                switch mapper(arg) {
                    case .success(let value): .succ(value, advanceBy: 1)
                    case .failure(let error): .fail("Failed to parse '\(arg)' CLI argument: \(error)", advanceBy: 1)
                }
        }
    }
}

func constSubArgParserFun<Value: Sendable>(_ const: Value) -> ArgParserFun<SubArgParserInput, Value> {
    return { _ in .succ(const, advanceBy: 0) }
}
