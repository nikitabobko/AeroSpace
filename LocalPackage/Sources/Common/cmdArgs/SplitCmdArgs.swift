public struct SplitCmdArgs: CmdArgs, RawCmdArgs {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .split,
        allowInConfig: true,
        help: """
              USAGE: split [-h|--help] \(SplitArg.unionLiteral)

              OPTIONS:
                -h, --help   Print help
              """,
        options: [:],
        arguments: [ArgParser(\.arg, parseSplitArg, argPlaceholderIfMandatory: SplitArg.unionLiteral)]
    )
    @Lateinit public var arg: SplitArg

    fileprivate init() {}

    public init(_ arg: SplitArg) {
        self.arg = arg
    }

    public enum SplitArg: String, CaseIterable {
        case horizontal, vertical, opposite
    }
}

public func parseSplitCmdArgs(_ args: [String]) -> ParsedCmd<SplitCmdArgs> {
    parseRawCmdArgs(SplitCmdArgs(), args)
}

private func parseSplitArg(arg: String, nextArgs: inout [String]) -> Parsed<SplitCmdArgs.SplitArg> {
    parseEnum(arg, SplitCmdArgs.SplitArg.self)
}
