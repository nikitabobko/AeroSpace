import Common

struct ExecAndForgetCmdArgs: CmdArgs {
    let bashScript: String
    public static let info: CmdStaticInfo = CmdStaticInfo(
        help: "USAGE: exec-and-forget <bash-script>",
        kind: .execAndForget,
        allowInConfig: true
    )
}

func parseExecAndForgetCmdArgs(_ nextArgs: String) -> ParsedCmd<ExecAndForgetCmdArgs> {
    .cmd(ExecAndForgetCmdArgs(bashScript: nextArgs))
}
