public struct EnableCmdArgs: CmdArgs {
    public static let info: CmdStaticInfo = RawEnableCmdArgs.info
    public let targetState: State

    public init(targetState: State) {
        self.targetState = targetState
    }

    public enum State: String, CaseIterable {
        case on, off, toggle
    }
}

public func parseEnableCmdArgs(_ args: [String]) -> ParsedCmd<EnableCmdArgs> {
    parseRawCmdArgs(RawEnableCmdArgs(), args)
        .flatMap { raw in
            guard let state = raw.targetState else { return .failure("enable argument is mandatory") }
            return .cmd(EnableCmdArgs(targetState: state))
        }
}

private struct RawEnableCmdArgs: RawCmdArgs {
    var targetState: EnableCmdArgs.State?

    static let parser: CmdParser<Self> = cmdParser(
        kind: .enable,
        allowInConfig: true,
        help: """
              USAGE: enable [-h|--help] \(EnableCmdArgs.State.unionLiteral)

              OPTIONS:
                -h, --help   Print help
              """,
        options: [:],
        arguments: [ArgParser(\.targetState, parseState)]
    )
}

private func parseState(_ raw: String) -> Parsed<EnableCmdArgs.State> {
    parseEnum(raw, EnableCmdArgs.State.self)
}
