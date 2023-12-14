struct FocusCmdArgs: CmdArgs, Equatable {
    let kind: CmdKind = .focus
    let boundaries: Boundaries
    let whenBoundariesCrossed: WhenBoundariesCrossed
    let direction: CardinalDirection
    enum Boundaries: String, CaseIterable, Equatable {
        case container
        case workspace
        case allMonitorsUnionFrame = "all-monitors-union-frame"
    }
    enum WhenBoundariesCrossed: String, CaseIterable, Equatable {
        case doNothing = "do-nothing"
        case wrapAroundTheContainer = "wrap-around-the-container"
        case wrapAroundTheWorkspace = "wrap-around-the-workspace"
        case wrapAroundAllMonitors = "wrap-around-all-monitors"
    }
}

private struct RawFocusCmdArgs: RawCmdArgs {
    var boundaries: FocusCmdArgs.Boundaries?
    var whenBoundariesCrossed: FocusCmdArgs.WhenBoundariesCrossed?
    var direction: CardinalDirection?

    static let info = CmdInfo<Self>(
        help: """
              USAGE: focus [-h|--help] [OPTIONS] (left|down|up|right)

              OPTIONS:
                -h, --help                          Print help
                --boundaries <boundary>             Defines focus boundaries.
                                                    <boundary> possible values:
                                                      \(FocusCmdArgs.Boundaries.container)
                                                      \(FocusCmdArgs.Boundaries.workspace)
                                                      \(FocusCmdArgs.Boundaries.allMonitorsUnionFrame)
                --when-boundaries-crossed <action>  Defines the behaviour when boundaries are crossed.
                                                    <action> possible values:
                                                      \(FocusCmdArgs.WhenBoundariesCrossed.doNothing)
                                                      \(FocusCmdArgs.WhenBoundariesCrossed.wrapAroundTheContainer)
                                                      \(FocusCmdArgs.WhenBoundariesCrossed.wrapAroundTheWorkspace)
                                                      \(FocusCmdArgs.WhenBoundariesCrossed.wrapAroundAllMonitors)
              ARGUMENTS:
                (left|down|up|right)                Focus direction
              """, // todo focus [OPTIONS] window-id <id>
        // ARGUMENTS:
        //  <id>                                  ID of window to focus
        options: [
            "--boundaries": ArgParser(\.boundaries, parseBoundaries),
            "--when-boundaries-crossed": ArgParser(\.whenBoundariesCrossed, parseWhenBoundariesCrossed)
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
            if raw.boundaries == .container && raw.whenBoundariesCrossed == .wrapAroundTheWorkspace ||
                   raw.boundaries == .container && raw.whenBoundariesCrossed == .wrapAroundAllMonitors ||
                   raw.boundaries == .workspace && raw.whenBoundariesCrossed == .wrapAroundAllMonitors {
                return .failure("\(raw.boundaries!) and \(raw.whenBoundariesCrossed!) is an invalid combination of values")
            }
            return .cmd(FocusCmdArgs(
                boundaries: raw.boundaries ?? .workspace,
                whenBoundariesCrossed: raw.whenBoundariesCrossed ?? .doNothing,
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
        return .failure("--when-boundaries-crossed option requires an argument: \(FocusCmdArgs.WhenBoundariesCrossed.unionLiteral)")
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
