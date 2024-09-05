public struct EnableCmdArgs: RawCmdArgs {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .enable,
        allowInConfig: true,
        help: """
            USAGE: enable [-h|--help] \(EnableCmdArgs.State.unionLiteral)

            OPTIONS:
              -h, --help   Print help
            """,
        options: [:],
        arguments: [newArgParser(\.targetState, parseState, mandatoryArgPlaceholder: EnableCmdArgs.State.unionLiteral)]
    )
    public var targetState: Lateinit<State> = .uninitialized

    public let rawArgs: EquatableNoop<[String]>
    init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }

    public init(rawArgs: [String], targetState: State) {
        self.rawArgs = .init(rawArgs)
        self.targetState = .initialized(targetState)
    }

    public enum State: String, CaseIterable {
        case on, off, toggle
    }
}

private func parseState(arg: String, nextArgs: inout [String]) -> Parsed<EnableCmdArgs.State> {
    parseEnum(arg, EnableCmdArgs.State.self)
}
