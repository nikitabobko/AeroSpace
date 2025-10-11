public struct MoveCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .move,
        allowInConfig: true,
        help: move_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
            "--boundaries": SubArgParser(\.rawBoundaries, upcastArgParserFun(parseBoundaries)),
            "--boundaries-action": SubArgParser(\.rawBoundariesAction, upcastArgParserFun(parseBoundariesAction)),
        ],
        posArgs: [newArgParser(\.direction, parseCardinalDirectionArg, mandatoryArgPlaceholder: CardinalDirection.unionLiteral)],
    )

    public var direction: Lateinit<CardinalDirection> = .uninitialized
    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var rawBoundaries: Boundaries? = nil
    public var rawBoundariesAction: WhenBoundariesCrossed? = nil

    public init(rawArgs: [String], _ direction: CardinalDirection) {
        self.rawArgsForStrRepr = .init(rawArgs)
        self.direction = .initialized(direction)
    }

    public enum Boundaries: String, CaseIterable, Equatable, Sendable {
        case workspace
        case allMonitorsOuterFrame = "all-monitors-outer-frame"
    }

    public enum WhenBoundariesCrossed: String, CaseIterable, Equatable, Sendable {
        case stop = "stop"
        case fail = "fail"
        case createImplicitContainer = "create-implicit-container"
    }
}

extension MoveCmdArgs {
    public var boundaries: Boundaries { rawBoundaries ?? .workspace }
    public var boundariesAction: WhenBoundariesCrossed { rawBoundariesAction ?? .createImplicitContainer }
}

public func parseMoveCmdArgs(_ args: [String]) -> ParsedCmd<MoveCmdArgs> {
    parseSpecificCmdArgs(MoveCmdArgs(rawArgs: args), args)
}

private func parseBoundaries(arg: String, nextArgs: inout [String]) -> Parsed<MoveCmdArgs.Boundaries> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return parseEnum(arg, MoveCmdArgs.Boundaries.self)
    } else {
        return .failure("<boundary> is mandatory")
    }
}

private func parseBoundariesAction(arg: String, nextArgs: inout [String]) -> Parsed<MoveCmdArgs.WhenBoundariesCrossed> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return parseEnum(arg, MoveCmdArgs.WhenBoundariesCrossed.self)
    } else {
        return .failure("<action> is mandatory")
    }
}
