let subcommandParsers: [String: any SubCommandParserProtocol] = initSubcommands()

func defaultSubCommandParser<T: CmdArgs>(_ raw: @escaping (EquatableNoop<[String]>) -> T) -> SubCommandParser<T> {
    SubCommandParser { args in parseRawCmdArgs(raw(.init(args)), args) }
}

func defaultSubCommandParser<T: CmdArgs>(_ raw: @escaping ([String]) -> T) -> SubCommandParser<T> {
    SubCommandParser { args in parseRawCmdArgs(raw(args), args) }
}

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
        self._parse = parser
    }
}
