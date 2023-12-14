struct ExecAndWaitCmdArgs: CmdArgs {
    let bashScript: String
    let kind: CmdKind = .execAndWait
}
struct ExecAndForgetCmdArgs: CmdArgs {
    let bashScript: String
    let kind: CmdKind = .execAndForget
}

func parseExecAndWaitCmdArgs(_ nextArgs: String) -> ParsedCmd<ExecAndWaitCmdArgs> {
    .cmd(ExecAndWaitCmdArgs(bashScript: nextArgs))
}

func parseExecAndForgetCmdArgs(_ nextArgs: String) -> ParsedCmd<ExecAndForgetCmdArgs> {
    .cmd(ExecAndForgetCmdArgs(bashScript: nextArgs))
}
