public struct DebugWindowsCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: EquatableNoop<[String]>) { self.rawArgs = rawArgs }
    public static let parser: CmdParser<Self> = noArgsParser(.debugWindows, allowInConfig: false)

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
