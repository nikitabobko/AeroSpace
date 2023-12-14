struct ModeCmdArgs: CmdArgs {
    let kind: CmdKind = .mode
    let targetMode: String
}

private struct RawModeCmdArgs: RawCmdArgs {
    var targetMode: String?

    static let info = CmdInfo<Self>(
        help: """
              USAGE: mode [-h|--help] <target-mode>

              OPTIONS:
                -h, --help      Print help

              ARGUMENTS:
                <target-mode>   Binding mode to activate
              """,
        options: [:],
        arguments: [ArgParser(\.targetMode, parseTargetMode)]
    )
}

func parseModeCmdArgs(_ args: [String]) -> ParsedCmd<ModeCmdArgs> {
    parseRawCmdArgs(RawModeCmdArgs(), args)
        .flatMap { raw in
            guard let mode = raw.targetMode else {
                return .failure("<target-mode> isn't specified")
            }
            return .cmd(ModeCmdArgs(targetMode: mode))
        }
}

private func parseTargetMode(_ arg: String) -> Parsed<String> { .success(arg) }