public struct ListExecEnvVarsCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listExecEnvVars,
        allowInConfig: true,
        help: list_exec_env_vars_help_generated,
        flags: [:],
        posArgs: [],
    )
}
