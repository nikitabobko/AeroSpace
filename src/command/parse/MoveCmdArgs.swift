import Common

struct MoveCmdArgs: CmdArgs {
    static let info: CmdStaticInfo = RawMoveCmdArgs.info
    let direction: CardinalDirection
}

private struct RawMoveCmdArgs: RawCmdArgs {
    var direction: CardinalDirection?

    static let parser: CmdParser<Self> = cmdParser(
        kind: .move,
        allowInConfig: true,
        help: """
              USAGE: move [-h|--help] \(CardinalDirection.unionLiteral)

              OPTIONS:
                -h, --help   Print help
              """,
        options: [:],
        arguments: [ArgParser(\.direction, parseCardinalDirection)]
    )
}

func parseMoveCmdArgs(_ args: [String]) -> ParsedCmd<MoveCmdArgs> {
    parseRawCmdArgs(RawMoveCmdArgs(), args)
        .flatMap { raw in
            guard let direction = raw.direction else {
                return .failure("move direction isn't specified")
            }
            return .cmd(MoveCmdArgs(
                direction: direction
            ))
        }
}
