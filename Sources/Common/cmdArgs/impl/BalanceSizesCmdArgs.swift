public struct BalanceSizesCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .balanceSizes,
        allowInConfig: true,
        help: balance_sizes_help_generated,
        flags: [
            "--workspace": optionalWorkspaceFlag(),
        ],
        posArgs: [],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
