public struct ModeCmdArgs: RawCmdArgs {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .mode,
        allowInConfig: true,
        help: """
              USAGE: mode [-h|--help] <binding-mode>

              OPTIONS:
                -h, --help      Print help

              ARGUMENTS:
                <binding-mode>   Binding mode to activate
              """,
        options: [:],
        arguments: [newArgParser(\.targetMode, parseTargetMode, mandatoryArgPlaceholder: "<binding-mode>")]
    )
    public var targetMode: Lateinit<String> = .uninitialized
}

private func parseTargetMode(arg: String, nextArgs: inout [String]) -> Parsed<String> {
    .success(arg)
}
