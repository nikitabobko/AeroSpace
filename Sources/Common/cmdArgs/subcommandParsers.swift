let subcommandParsers: [String: any SubCommandParserProtocol] = initSubcommands()

protocol SubCommandParserProtocol<T> {
    associatedtype T where T: CmdArgs
    var _parse: ([String]) -> ParsedCmd<T> { get }
}

extension SubCommandParserProtocol {
    func parse(args: [String]) -> ParsedCmd<any CmdArgs> {
        _parse(args).map { $0 }
    }
}

struct SubCommandParser<T: CmdArgs>: SubCommandParserProtocol {
    let _parse: ([String]) -> ParsedCmd<T>

    init(_ parser: @escaping ([String]) -> ParsedCmd<T>) {
        _parse = parser
    }

    init(_ raw: @escaping (EquatableNoop<[String]>) -> T) {
        _parse = { args in parseRawCmdArgs(raw(.init(args)), args) }
    }

    init(_ raw: @escaping ([String]) -> T) {
        _parse = { args in parseRawCmdArgs(raw(args), args) }
    }
}
