let subcommandParsers: [String: any SubCommandParserProtocol] = initSubcommands()

protocol SubCommandParserProtocol<T>: Sendable {
    associatedtype T where T: CmdArgs
    var _parse: @Sendable ([String]) -> ParsedCmd<T> { get }
}

extension SubCommandParserProtocol {
    func parse(args: [String]) -> ParsedCmd<any CmdArgs> {
        _parse(args).map { $0 }
    }
}

struct SubCommandParser<T: CmdArgs>: SubCommandParserProtocol, Sendable {
    let _parse: @Sendable ([String]) -> ParsedCmd<T>

    init(_ parser: @escaping @Sendable ([String]) -> ParsedCmd<T>) {
        _parse = parser
    }

    init(_ raw: @escaping @Sendable (EquatableNoop<[String]>) -> T) {
        _parse = { args in parseSpecificCmdArgs(raw(.init(args)), args) }
    }

    init(_ raw: @escaping @Sendable ([String]) -> T) {
        _parse = { args in parseSpecificCmdArgs(raw(args), args) }
    }
}
