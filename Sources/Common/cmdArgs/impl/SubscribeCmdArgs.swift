public struct SubscribeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) {
        self.commonState = .init(rawArgs)
    }
    public static let parser: CmdParser<Self> = .init(
        kind: .subscribe,
        allowInConfig: false,
        help: subscribe_help_generated,
        flags: [
            "--all": trueBoolFlag(\.allAlias),
            "--no-send-initial": falseBoolFlag(\.sendInitial),
        ],
        posArgs: [ArgParser(\.events, parseEventTypes)],
    )

    fileprivate var allAlias: Bool = false
    public var sendInitial = true
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
    var errorMsg: String? = nil
    for arg in args {
        switch parseEnum(arg, ServerEventType.self) {
            case .success(let event):
                if events.contains(event) {
                    errorMsg = "Duplicate event '\(arg)'"
                }
                events.insert(event)
            case .failure(let errorMsg):
                return .fail(errorMsg, advanceBy: events.count + 1)
        }
    }
    if let errorMsg {
        return .fail(errorMsg, advanceBy: args.count)
    } else {
        return .succ(events, advanceBy: args.count)
    }
}

public enum ServerEventType: String, Codable, CaseIterable, Sendable {
    case focusChanged = "focus-changed"
    case focusedMonitorChanged = "focused-monitor-changed"
    case workspaceChanged = "focused-workspace-changed"
    case modeChanged = "mode-changed"
    case windowDetected = "window-detected"
    case bindingTriggered = "binding-triggered"
    case monitorChanged = "monitor-changed"
}
