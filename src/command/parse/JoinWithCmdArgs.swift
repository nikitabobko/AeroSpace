import Common

struct JoinWithCmdArgs: CmdArgs {
    static let info: CmdStaticInfo = RawJoinWithCmdArgs.info
    let direction: CardinalDirection
}

private struct RawJoinWithCmdArgs: RawCmdArgs {
    var direction: CardinalDirection?

    static let parser: CmdParser<Self> = cmdParser(
        kind: .joinWith,
        allowInConfig: true,
        help: """
              USAGE: join-with [-h|--help] \(CardinalDirection.unionLiteral)

              OPTIONS:
                -h, --help   Print help
              """,
        options: [:],
        arguments: [ArgParser(\.direction, parseCardinalDirection)]
    )
}

func parseJoinWithCmdArgs(_ args: [String]) -> ParsedCmd<JoinWithCmdArgs> {
    parseRawCmdArgs(RawJoinWithCmdArgs(), args)
        .flatMap { raw in
            guard let direction = raw.direction else {
                return .failure("join-with direction isn't specified")
            }
            return .cmd(JoinWithCmdArgs(
                direction: direction
            ))
        }
}
