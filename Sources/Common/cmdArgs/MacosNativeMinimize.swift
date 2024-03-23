public struct MacosNativeMinimizeCmdArgs: RawCmdArgs, CmdArgs {
    public init() {}
    public static let parser: CmdParser<Self> = noArgsParser(.macosNativeMinimize, allowInConfig: true)
}
