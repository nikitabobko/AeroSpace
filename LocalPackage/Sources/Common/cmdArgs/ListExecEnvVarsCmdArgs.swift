public struct ListExecEnvVarsCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.listExecEnvVars, allowInConfig: true)
}
