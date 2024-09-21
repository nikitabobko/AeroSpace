public struct MacosNativeMinimizeCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .macosNativeMinimize,
        allowInConfig: true,
        help: macos_native_minimize_help_generated,
        options: [:],
        arguments: []
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
