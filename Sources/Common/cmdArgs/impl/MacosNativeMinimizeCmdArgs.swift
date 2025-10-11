public struct MacosNativeMinimizeCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<[String]>
    public init(rawArgs: [String]) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .macosNativeMinimize,
        allowInConfig: true,
        help: macos_native_minimize_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
        ],
        posArgs: [],
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
}
