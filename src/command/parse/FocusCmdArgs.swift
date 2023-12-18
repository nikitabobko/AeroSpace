import Common

struct FocusCmdArgs: CmdArgs, Equatable {
    static let info: CmdStaticInfo = RawFocusCmdArgs.info

    let boundaries: Boundaries // todo cover boundaries wrapping with tests
    let boundariesAction: WhenBoundariesCrossed
    let direction: CardinalDirection
    enum Boundaries: String, CaseIterable, Equatable {
        case workspace
        case allMonitorsUnionFrame = "all-monitors-outer-frame"
    }
    enum WhenBoundariesCrossed: String, CaseIterable, Equatable {
        case stop = "stop"
        case wrapAroundTheWorkspace = "wrap-around-the-workspace"
        case wrapAroundAllMonitors = "wrap-around-all-monitors"
    }
}

private struct RawFocusCmdArgs: RawCmdArgs {
    var boundaries: FocusCmdArgs.Boundaries?
    var boundariesAction: FocusCmdArgs.WhenBoundariesCrossed?
    var direction: CardinalDirection?

    static let parser: CmdParser<Self> = cmdParser(
        kind: .focus,
        allowInConfig: true,
        help: """
              USAGE: focus [<OPTIONS>] (left|down|up|right)

              OPTIONS:
                -h, --help                     Print help
                --boundaries <boundary>        Defines focus boundaries.
                                               <boundary> possible values: \(FocusCmdArgs.Boundaries.unionLiteral)
                                               The default is: \(FocusCmdArgs.Boundaries.workspace.rawValue)
                --boundaries-action <action>   Defines the behavior when requested to cross the <boundary>.
                                               <action> possible values: \(FocusCmdArgs.WhenBoundariesCrossed.unionLiteral)
                                               The default is: \(FocusCmdArgs.WhenBoundariesCrossed.wrapAroundTheWorkspace.rawValue)

              ARGUMENTS:
                (left|down|up|right)           Focus direction
              """, // todo focus [OPTIONS] window-id <id>
        // ARGUMENTS:
        //  <id>                                  ID of window to focus
        options: [
            "--boundaries": ArgParser(\.boundaries, parseBoundaries),
            "--boundaries-action": ArgParser(\.boundariesAction, parseWhenBoundariesCrossed)
        ],
        arguments: [ArgParser(\.direction, parseCardinalDirection)]
    )
}

func parseFocusCmdArgs(_ args: [String]) -> ParsedCmd<FocusCmdArgs> {
    parseRawCmdArgs(RawFocusCmdArgs(), args)
        .flatMap { raw in
            guard let direction = raw.direction else {
                return .failure("focus direction isn't specified")
            }
            if raw.boundaries == .workspace && raw.boundariesAction == .wrapAroundAllMonitors {
                return .failure("\(raw.boundaries!.rawValue) and \(raw.boundariesAction!.rawValue) is an invalid combination of values")
            }
            return .cmd(FocusCmdArgs(
                boundaries: raw.boundaries ?? .workspace,
                boundariesAction: raw.boundariesAction ?? .wrapAroundTheWorkspace,
                direction: direction
            ))
        }
}

func parseCardinalDirection(_ direction: String) -> Parsed<CardinalDirection> {
    parseEnum(direction, CardinalDirection.self)
}

private func parseWhenBoundariesCrossed(_ nextArgs: inout [String]) -> Parsed<FocusCmdArgs.WhenBoundariesCrossed> {
    if let arg = nextArgs.nextOrNil() {
        return parseEnum(arg, FocusCmdArgs.WhenBoundariesCrossed.self)
    } else {
        return .failure("--boundaries-action option requires an argument: \(FocusCmdArgs.WhenBoundariesCrossed.unionLiteral)")
    }
}

private func parseBoundaries(_ nextArgs: inout [String]) -> Parsed<FocusCmdArgs.Boundaries> {
    if let arg = nextArgs.nextOrNil() {
        return parseEnum(arg, FocusCmdArgs.Boundaries.self)
    } else {
        return .failure("--boundaries option requires an argument: \(FocusCmdArgs.Boundaries.unionLiteral)")
    }
}

// todo reuse in config
func parseEnum<T: RawRepresentable>(_ raw: String, _ _: T.Type) -> Parsed<T> where T.RawValue == String, T: CaseIterable {
    T(rawValue: raw).orFailure { "Can't parse '\(raw)'.\nPossible values: \(T.unionLiteral)" }
}
