public struct DebugWindowsCmdArgs: RawCmdArgs, CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: EquatableNoop<[String]>) { self.rawArgs = rawArgs }
    public static let parser: CmdParser<Self> = noArgsParser(.debugWindows, allowInConfig: false)
}
