public struct ScrollCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .scroll,
        allowInConfig: true,
        help: scroll_help_generated,
        flags: [:],
        posArgs: [newMandatoryPosArgParser(\.direction, parseScrollDirection, placeholder: ScrollDirection.unionLiteral)],
    )

    public var direction: Lateinit<ScrollDirection> = .uninitialized

    public init(rawArgs: [String], direction: ScrollDirection) {
        self.commonState = .init(rawArgs.slice)
        self.direction = .initialized(direction)
    }
}

public enum ScrollDirection: String, CaseIterable, Equatable, Sendable {
    case left, right
}

private func parseScrollDirection(input: PosArgParserInput) -> ParsedCliArgs<ScrollDirection> {
    .init(parseEnum(input.arg, ScrollDirection.self), advanceBy: 1)
}

func parseScrollCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ScrollCmdArgs> {
    parseSpecificCmdArgs(ScrollCmdArgs(rawArgs: args), args)
}
