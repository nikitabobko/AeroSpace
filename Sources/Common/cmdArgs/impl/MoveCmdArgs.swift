private let boundar = "<boundary>"
private let actio = "<action>"

public struct MoveCmdArgs: CmdArgs {
    public let rawArgs: EquatableNoop<[String]>
    fileprivate init(rawArgs: [String]) { self.rawArgs = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .move,
        allowInConfig: true,
        help: move_help_generated,
        options: [
            "--window-id": optionalWindowIdFlag(),
            "--boundaries": ArgParser(\.rawBoundaries, upcastArgParserFun(parseBoundaries)),
            "--boundaries-action": ArgParser(\.rawBoundariesAction, upcastArgParserFun(parseBoundariesAction)),
        ],
        arguments: [newArgParser(\.direction, parseCardinalDirectionArg, mandatoryArgPlaceholder: CardinalDirection.unionLiteral)]
    )

    public var direction: Lateinit<CardinalDirection> = .uninitialized
    public var windowId: UInt32?
    public var workspaceName: WorkspaceName?
    public var rawBoundaries: Boundaries? = nil
    public var rawBoundariesAction: WhenBoundariesCrossed? = nil

    public init(rawArgs: [String], _ direction: CardinalDirection) {
        self.rawArgs = .init(rawArgs)
        self.direction = .initialized(direction)
    }

    public enum Boundaries: String, CaseIterable, Equatable, Sendable {
        case workspace
        case allMonitorsUnionFrame = "all-monitors-outer-frame"
    }

    public enum WhenBoundariesCrossed: String, CaseIterable, Equatable, Sendable {
        case stop = "stop"
        case fail = "fail"
        case createImplicitContainer = "create-implicit-container"
    }
}

public extension MoveCmdArgs {
    var boundaries: Boundaries { rawBoundaries ?? .workspace }
    var boundariesAction: WhenBoundariesCrossed { rawBoundariesAction ?? .createImplicitContainer }
}

public func parseMoveCmdArgs(_ args: [String]) -> ParsedCmd<MoveCmdArgs> {
    parseSpecificCmdArgs(MoveCmdArgs(rawArgs: args), args)
}

private func parseBoundaries(arg: String, nextArgs: inout [String]) -> Parsed<MoveCmdArgs.Boundaries> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return parseEnum(arg, MoveCmdArgs.Boundaries.self)
    } else {
        return .failure("\(boundar) is mandatory")
    }
}

private func parseBoundariesAction(arg: String, nextArgs: inout [String]) -> Parsed<MoveCmdArgs.WhenBoundariesCrossed> {
    if let arg = nextArgs.nextNonFlagOrNil() {
        return parseEnum(arg, MoveCmdArgs.WhenBoundariesCrossed.self)
    } else {
        return .failure("\(actio) is mandatory")
    }
}
