public struct ModeCmdArgs: CmdArgs {
    public static let info: CmdStaticInfo = RawModeCmdArgs.info
    public let targetMode: String
}

private struct RawModeCmdArgs: RawCmdArgs {
    @Lateinit var targetMode: String

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
        arguments: [ArgParser(\.targetMode, parseTargetMode, argPlaceholderIfMandatory: "<binding-mode>")]
    )
}

public func parseModeCmdArgs(_ args: [String]) -> ParsedCmd<ModeCmdArgs> {
    parseRawCmdArgs(RawModeCmdArgs(), args)
        .flatMap { raw in .cmd(ModeCmdArgs(targetMode: raw.targetMode)) }
}

private func parseTargetMode(arg: String, nextArgs: inout [String]) -> Parsed<String> { .success(arg) }
