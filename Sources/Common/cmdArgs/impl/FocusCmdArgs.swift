public struct FocusCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .focus,
        allowInConfig: true,
        help: focus_help_generated,
        options: [
            "--ignore-floating": falseBoolFlag(\.floatingAsTiling),
            "--boundaries": ArgParser(\.rawBoundaries, upcastArgParserFun(parseBoundaries)),
            "--boundaries-action": ArgParser(\.rawBoundariesAction, upcastArgParserFun(parseBoundariesAction)),
            "--window-id": ArgParser(\.windowId, upcastArgParserFun(parseArgWithUInt32)),
            "--dfs-index": ArgParser(\.dfsIndex, upcastArgParserFun(parseArgWithUInt32)),
        ],
        arguments: [ArgParser(\.cardinalOrDfsDirection, upcastArgParserFun(parseCardinalOrDfsDirection))],
    )

    public var rawBoundaries: Boundaries? = nil // todo cover boundaries wrapping with tests
    public var rawBoundariesAction: WhenBoundariesCrossed? = nil
    public var dfsIndex: UInt32? = nil
    public var cardinalOrDfsDirection: CardinalOrDfsDirection? = nil
    public var floatingAsTiling: Bool = true
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public init(rawArgs: [String], cardinalOrDfsDirection: CardinalOrDfsDirection) {
        self.rawArgs = .init(rawArgs)
        self.cardinalOrDfsDirection = cardinalOrDfsDirection
    }

    public init(rawArgs: [String], windowId: UInt32) {
        self.rawArgs = .init(rawArgs)
        self.windowId = windowId
    }

    public init(rawArgs: [String], dfsIndex: UInt32) {
        self.rawArgs = .init(rawArgs)
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

public func parseFocusCmdArgs(_ args: [String]) -> ParsedCmd<FocusCmdArgs> {
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

private func parseBoundariesAction(arg: String, nextArgs: inout [String]) -> Parsed<FocusCmdArgs.WhenBoundariesCrossed> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return parseEnum(arg, FocusCmdArgs.WhenBoundariesCrossed.self)
    } else {
        return .failure("<action> is mandatory")
    }
}

private func parseBoundaries(arg: String, nextArgs: inout [String]) -> Parsed<FocusCmdArgs.Boundaries> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return parseEnum(arg, FocusCmdArgs.Boundaries.self)
    } else {
        return .failure("<boundary> is mandatory")
    }
}
