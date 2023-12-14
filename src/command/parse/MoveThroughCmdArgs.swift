struct MoveThroughCmdArgs: CmdArgs {
    let kind: CmdKind = .moveThrough
    let direction: CardinalDirection
}

private struct RawMoveThroughCmdArgs: RawCmdArgs {
    var direction: CardinalDirection?

    static let info = CmdInfo<Self>(
        help: """
              USAGE: move-through [-h|--help] \(CardinalDirection.unionLiteral)

              OPTIONS:
                -h, --help   Print help
              """,
        options: [:],
        arguments: [ArgParser(\.direction, parseCardinalDirection)]
    )
}

func parseMoveThroughCmdArgs(_ args: [String]) -> ParsedCmd<MoveThroughCmdArgs> {
    parseRawCmdArgs(RawMoveThroughCmdArgs(), args)
        .flatMap { raw in
            guard let direction = raw.direction else {
                return .failure("move-through direction isn't specified")
            }
            return .cmd(MoveThroughCmdArgs(
                direction: direction
            ))
        }
}
