struct JoinWithCmdArgs: CmdArgs {
    let kind: CmdKind = .joinWith
    let direction: CardinalDirection
}

private struct RawJoinWithCmdArgs: RawCmdArgs {
    var direction: CardinalDirection?

    static let info = CmdInfo<Self>(
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
