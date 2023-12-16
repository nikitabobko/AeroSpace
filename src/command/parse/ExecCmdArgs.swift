struct ExecAndWaitCmdArgs: CmdArgs {
    let bashScript: String
    let kind: CmdKind = .execAndWait
    static let info: CmdStaticInfo = CmdStaticInfo(
        help: "USAGE: exec-and-wait <bash-script>",
        kind: .execAndWait,
        allowInConfig: true
    )
}
struct ExecAndForgetCmdArgs: CmdArgs {
    let bashScript: String
    static let info: CmdStaticInfo = CmdStaticInfo(
        help: "USAGE: exec-and-forget <bash-script>",
        kind: .execAndForget,
        allowInConfig: true
    )
}

func parseExecAndWaitCmdArgs(_ nextArgs: String) -> ParsedCmd<ExecAndWaitCmdArgs> {
    .cmd(ExecAndWaitCmdArgs(bashScript: nextArgs))
}

func parseExecAndForgetCmdArgs(_ nextArgs: String) -> ParsedCmd<ExecAndForgetCmdArgs> {
    .cmd(ExecAndForgetCmdArgs(bashScript: nextArgs))
}
