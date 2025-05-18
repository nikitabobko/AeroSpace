public struct NoopCmdArgs: CmdArgs {
	public let rawArgs: EquatableNoop<[String]>
	public init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
	public static let parser: CmdParser<Self> = cmdParser(
		kind: .noop,  // This will require adding .noop to CmdKind
		allowInConfig: true,
		help: "Does nothing. Useful for clearing a previously bound hotkey or for testing.",
		options: [:],
		arguments: []
	)

	public var windowId: UInt32?
	public var workspaceName: WorkspaceName?
}

// We might not need a custom parse function if the default behavior of parseSpecificCmdArgs is sufficient
// public func parseNoopCmdArgs(_ args: [String]) -> ParsedCmd<NoopCmdArgs> {
//     parseSpecificCmdArgs(NoopCmdArgs(rawArgs: args), args)
// }
