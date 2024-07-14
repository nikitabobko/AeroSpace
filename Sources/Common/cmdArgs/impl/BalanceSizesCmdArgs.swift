public struct BalanceSizesCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .balanceSizes,
        allowInConfig: true,
        help: balance_sizes_help_generated,
        options: [
            "--workspace": optionalWorkspaceFlag(),
        ],
        arguments: []
    )

    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
}
