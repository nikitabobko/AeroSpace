public struct SplitCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .split,
        allowInConfig: true,
        help: split_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [newArgParser(\.arg, parseSplitArg, mandatoryArgPlaceholder: SplitArg.unionLiteral)],
    )

    public var arg: Lateinit<SplitArg> = .uninitialized
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], _ arg: SplitArg) {
        self.rawArgsForStrRepr = .init(rawArgs)
        self.arg = .initialized(arg)
    }

    public enum SplitArg: String, CaseIterable, Sendable {
        case horizontal, vertical, opposite
    }
}

public func parseSplitCmdArgs(_ args: [String]) -> ParsedCmd<SplitCmdArgs> {
    parseSpecificCmdArgs(SplitCmdArgs(rawArgs: args), args)
}

private func parseSplitArg(arg: String, nextArgs: inout [String]) -> Parsed<SplitCmdArgs.SplitArg> {
    parseEnum(arg, SplitCmdArgs.SplitArg.self)
}
