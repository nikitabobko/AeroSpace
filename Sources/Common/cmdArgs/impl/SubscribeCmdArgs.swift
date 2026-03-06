public struct SubscribeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) {
        self.commonState = .init(rawArgs)
    }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .subscribe,
        allowInConfig: false,
        help: subscribe_help_generated,
        flags: [
            "--all": trueBoolFlag(\.allAlias),
        ],
        posArgs: [ArgParser(\.events, parseEventTypes)],
    )

    fileprivate var allAlias: Bool = false
    public var events: Set<ServerEventType> = []
}

public func parseSubscribeCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SubscribeCmdArgs> {
    parseSpecificCmdArgs(SubscribeCmdArgs(rawArgs: args), args)
        .filter("Either --all or at least one <event> must be specified") { raw in
            raw.allAlias || !raw.events.isEmpty
        }
        .filter("--all conflicts with specifying individual events") { raw in
            raw.allAlias.implies(raw.events.isEmpty)
        }
        .map { raw in
            raw.allAlias ? raw.copy(\.events, Set(ServerEventType.allCases)).copy(\.allAlias, false) : raw
        }
}

private func parseEventTypes(_ input: ArgParserInput) -> ParsedCliArgs<Set<ServerEventType>> {
    let args = input.nonFlagArgs()
    var events: Set<ServerEventType> = []
    for arg in args {
        guard let event = ServerEventType(rawValue: arg) else {
            let validEvents = ServerEventType.allCases.map(\.rawValue).joined(separator: ", ")
            return .fail("Unknown event '\(arg)'. Valid events: \(validEvents)", advanceBy: events.count + 1)
        }
        if events.contains(event) {
            return .fail("Duplicate event '\(arg)'", advanceBy: events.count + 1)
        }
        events.insert(event)
    }
    return .succ(events, advanceBy: args.count)
}
