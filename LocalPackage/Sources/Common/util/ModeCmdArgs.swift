import Common

public struct ModeCmdArgs: CmdArgs {
    public static let info: CmdStaticInfo = RawModeCmdArgs.info
    public let targetMode: String
}

private struct RawModeCmdArgs: RawCmdArgs {
    var targetMode: String?

    static let parser: CmdParser<Self> = cmdParser(
        kind: .mode,
        allowInConfig: true,
        help: """
              USAGE: mode [-h|--help] <binding-mode>

              OPTIONS:
                -h, --help      Print help

              ARGUMENTS:
                <target-mode>   Binding mode to activate
              """,
        options: [:],
        arguments: [ArgParser(\.targetMode, parseTargetMode)]
    )
}

public func parseModeCmdArgs(_ args: [String]) -> ParsedCmd<ModeCmdArgs> {
    parseRawCmdArgs(RawModeCmdArgs(), args)
        .flatMap { raw in
            guard let mode = raw.targetMode else {
                return .failure("<target-mode> isn't specified")
            }
            return .cmd(ModeCmdArgs(targetMode: mode))
        }
}

private func parseTargetMode(_ arg: String) -> Parsed<String> { .success(arg) }
