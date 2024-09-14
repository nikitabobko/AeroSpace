public struct MacosNativeMinimizeCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = noArgsParser(.macosNativeMinimize, allowInConfig: true)

    public var windowId: UInt32?
    public var workspaceName: String?
}
