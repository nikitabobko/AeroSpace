let subcommandParsers: [String: any SubCommandParserProtocol] = initSubcommands()

protocol SubCommandParserProtocol<T>: Sendable {
    associatedtype T where T: CmdArgs
    var _parse: @Sendable (StrArrSlice) -> ParsedCmd<T> { get }
}

extension SubCommandParserProtocol {
    func parse(args: StrArrSlice) -> ParsedCmd<any CmdArgs> {
        _parse(args).map { $0 }
    }
}

struct SubCommandParser<T: CmdArgs>: SubCommandParserProtocol, Sendable {
    let _parse: @Sendable (StrArrSlice) -> ParsedCmd<T>

    init(_ parser: @escaping @Sendable (StrArrSlice) -> ParsedCmd<T>) {
        _parse = parser
    }

    init(_ raw: @escaping @Sendable (StrArrSlice) -> T) {
        _parse = { args in parseSpecificCmdArgs(raw(args), args) }
    }
}
