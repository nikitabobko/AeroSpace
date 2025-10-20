public struct FocusCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    fileprivate init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .focus,
        allowInConfig: true,
        help: focus_help_generated,
        flags: [
            "--ignore-floating": falseBoolFlag(\.floatingAsTiling),
            "--boundaries": SubArgParser(\.rawBoundaries, upcastSubArgParserFun(parseBoundaries)),
            "--boundaries-action": SubArgParser(\.rawBoundariesAction, upcastSubArgParserFun(parseBoundariesAction)),
            "--window-id": SubArgParser(\.windowId, upcastSubArgParserFun(parseUInt32SubArg)),
            "--dfs-index": SubArgParser(\.dfsIndex, upcastSubArgParserFun(parseUInt32SubArg)),
        ],
        posArgs: [ArgParser(\.cardinalOrDfsDirection, upcastArgParserFun(parseCardinalOrDfsDirection))],
    )

    public var rawBoundaries: Boundaries? = nil // todo cover boundaries wrapping with tests
    public var rawBoundariesAction: WhenBoundariesCrossed? = nil
    public var dfsIndex: UInt32? = nil
    public var cardinalOrDfsDirection: CardinalOrDfsDirection? = nil
    public var floatingAsTiling: Bool = true
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public init(rawArgs: StrArrSlice, cardinalOrDfsDirection: CardinalOrDfsDirection) {
        self.rawArgsForStrRepr = .init(rawArgs)
        self.cardinalOrDfsDirection = cardinalOrDfsDirection
    }

    public init(rawArgs: StrArrSlice, windowId: UInt32) {
        self.rawArgsForStrRepr = .init(rawArgs)
        self.windowId = windowId
    }

    public init(rawArgs: StrArrSlice, dfsIndex: UInt32) {
        self.rawArgsForStrRepr = .init(rawArgs)
        self.dfsIndex = dfsIndex
    }

    public enum Boundaries: String, CaseIterable, Equatable, Sendable {
        case workspace
        case allMonitorsOuterFrame = "all-monitors-outer-frame"
    }
    public enum WhenBoundariesCrossed: String, CaseIterable, Equatable, Sendable {
        case stop = "stop"
        case fail = "fail"
        case wrapAroundTheWorkspace = "wrap-around-the-workspace"
        case wrapAroundAllMonitors = "wrap-around-all-monitors"
    }
}

public enum FocusCmdTarget {
    case direction(CardinalDirection)
    case windowId(UInt32)
    case dfsIndex(UInt32)
    case dfsRelative(DfsNextPrev)

    var isDfsRelative: Bool {
        if case .dfsRelative = self {
            return true
        } else {
            return false
        }
    }
}

extension FocusCmdArgs {
    public var target: FocusCmdTarget {
        if let cardinalOrDfsDirection {
            return switch cardinalOrDfsDirection {
                case .direction(let dir): .direction(dir)
                case .dfsRelative(let nextPrev): .dfsRelative(nextPrev)
            }
        }
        if let windowId {
            return .windowId(windowId)
        }
        if let dfsIndex {
            return .dfsIndex(dfsIndex)
        }
        die("Parser invariants are broken")
    }

    public var boundaries: Boundaries { rawBoundaries ?? .workspace }
    public var boundariesAction: WhenBoundariesCrossed { rawBoundariesAction ?? .stop }
}

public func parseFocusCmdArgs(_ args: StrArrSlice) -> ParsedCmd<FocusCmdArgs> {
    return parseSpecificCmdArgs(FocusCmdArgs(rawArgs: args), args)
        .flatMap { (raw: FocusCmdArgs) -> ParsedCmd<FocusCmdArgs> in
            raw.boundaries == .workspace && raw.boundariesAction == .wrapAroundAllMonitors
                ? .failure("\(raw.boundaries.rawValue) and \(raw.boundariesAction.rawValue) is an invalid combination of values")
                : .cmd(raw)
        }
        .filter("Mandatory argument is missing. \(CardinalOrDfsDirection.unionLiteral), --window-id or --dfs-index is required") {
            $0.cardinalOrDfsDirection != nil || $0.windowId != nil || $0.dfsIndex != nil
        }
        .filter("--window-id is incompatible with other options") {
            $0.windowId == nil || $0 == FocusCmdArgs(rawArgs: args, windowId: $0.windowId.orDie())
        }
        .filter("--dfs-index is incompatible with other options") {
            $0.dfsIndex == nil || $0 == FocusCmdArgs(rawArgs: args, dfsIndex: $0.dfsIndex.orDie())
        }
        .filter("(dfs-next|dfs-prev) only supports --boundaries workspace") {
            $0.target.isDfsRelative.implies($0.boundaries == .workspace)
        }
}

private func parseBoundariesAction(i: SubArgParserInput) -> ParsedCliArgs<FocusCmdArgs.WhenBoundariesCrossed> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(parseEnum(arg, FocusCmdArgs.WhenBoundariesCrossed.self), advanceBy: 1)
    } else {
        return .fail("<action> is mandatory", advanceBy: 0)
    }
}

private func parseBoundaries(i: SubArgParserInput) -> ParsedCliArgs<FocusCmdArgs.Boundaries> {
    if let arg = i.nonFlagArgOrNil() {
        return .init(parseEnum(arg, FocusCmdArgs.Boundaries.self), advanceBy: 1)
    } else {
        return .fail("<boundary> is mandatory", advanceBy: 0)
    }
}
