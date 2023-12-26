public struct ModeCmdArgs: CmdArgs {
    public static let info: CmdStaticInfo = RawModeCmdArgs.info
    public let targetMode: String
}

private struct RawModeCmdArgs: RawCmdArgs {
    var targetMode: Lateinit<String> = .uninitialized

    static let parser: CmdParser<Self> = cmdParser(
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
        arguments: [newArgParser(\.targetMode, parseTargetMode, argPlaceholderIfMandatory: "<binding-mode>")]
    )
}

public func parseModeCmdArgs(_ args: [String]) -> ParsedCmd<ModeCmdArgs> {
    parseRawCmdArgs(RawModeCmdArgs(), args)
        .flatMap { raw in .cmd(ModeCmdArgs(targetMode: raw.targetMode.val)) }
}

private func parseTargetMode(arg: String, nextArgs: inout [String]) -> Parsed<String> { .success(arg) }
