public struct DebugWindowsCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.debugWindows, allowInConfig: false)
}
