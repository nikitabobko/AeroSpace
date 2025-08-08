public struct LayoutCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .layout,
        allowInConfig: true,
        help: layout_help_generated,
        options: [
            "--window-id": optionalWindowIdFlag(),
        ],
        arguments: [newArgParser(\.toggleBetween, parseToggleBetween, mandatoryArgPlaceholder: LayoutDescription.unionLiteral)],
    )

    public var toggleBetween: Lateinit<[LayoutDescription]> = .uninitialized
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], toggleBetween: [LayoutDescription]) {
        self.rawArgs = .init(rawArgs)
        self.toggleBetween = .initialized(toggleBetween)
    }
}

private func parseToggleBetween(arg: String, _ nextArgs: inout [String]) -> Parsed<[LayoutDescription]> {
    var args: [String] = nextArgs.allNextNonFlagArgs()
    args.insert(arg, at: 0)

    var result: [LayoutDescription] = []
    for arg in args {
        if let layout = parseLayoutDescription(arg) {
            result.append(layout)
        } else {
            return .failure("Can't parse '\(arg)'\nPossible values: \(LayoutDescription.unionLiteral)")
        }
    }

    return .success(result)
}

public func parseLayoutCmdArgs(_ args: [String]) -> ParsedCmd<LayoutCmdArgs> {
    parseSpecificCmdArgs(LayoutCmdArgs(rawArgs: args), args).map {
        check(!$0.toggleBetween.val.isEmpty)
        return $0
    }
}
