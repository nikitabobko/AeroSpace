protocol RawCmdArgs: Copyable {
    init()
    static var parser: CmdParser<Self> { get }
}

extension RawCmdArgs {
    static var info: CmdStaticInfo { Self.parser.info }
}

protocol CmdArgs {
    static var info: CmdStaticInfo { get }
}

struct CmdParser<T : Copyable> { // todo rename to CmdParser
    let info: CmdStaticInfo
    let options: [String: any ArgParserProtocol<T>]
    let arguments: [any ArgParserProtocol<T>]
}

func cmdParser<T>(
    kind: CmdKind,
    allowInConfig: Bool,
    help: String,
    options: [String: any ArgParserProtocol<T>],
    arguments: [any ArgParserProtocol<T>]
) -> CmdParser<T> {
    CmdParser(
        info: CmdStaticInfo(help: help, kind: kind, allowInConfig: allowInConfig),
        options: options,
        arguments: arguments
    )
}

struct CmdStaticInfo: Equatable {
    let help: String
    let kind: CmdKind
    let allowInConfig: Bool
}

enum ParsedCmd<T> {
    case cmd(T)
    case help(String)
    case failure(String)

    func map<R>(_ mapper: (T) -> R) -> ParsedCmd<R> {
        flatMap { .cmd(mapper($0)) }
    }

    func flatMap<R>(_ mapper: (T) -> ParsedCmd<R>) -> ParsedCmd<R> {
        switch self {
        case .cmd(let cmd):
            return mapper(cmd)
        case .help(let help):
            return .help(help)
        case .failure(let fail):
            return .failure(fail)
        }
    }

    func unwrap() -> (T?, String?, String?) {
        var command: T? = nil
        var error: String? = nil
        var help: String? = nil
        switch self {
        case .cmd(let _command):
            command = _command
        case .help(let _help):
            help = _help
        case .failure(let _error):
            error = _error
        }
        return (command, help, error)
    }
}

func parseRawCmdArgs<T : RawCmdArgs>(_ raw: T, _ args: [String]) -> ParsedCmd<T> {
    var args = args
    var raw = raw
    var errors: [String] = []

    var argumentIndex = 0

    while !args.isEmpty {
        let arg = args.next()
        if arg == "-h" || arg == "--help" {
            return .help(T.info.help)
        } else if let optionParser: any ArgParserProtocol<T> = T.parser.options[arg] {
            raw = optionParser.transformRaw(raw, arg, &args, &errors)
        } else if let parser = T.parser.arguments.getOrNil(atIndex: argumentIndex) {
            raw = parser.transformRaw(raw, arg, &args, &errors)
            argumentIndex += 1
        } else {
            errors.append("Unknown argument '\(arg)'")
            break
        }
    }

    return errors.isEmpty ? .cmd(raw) : .failure(errors.joinErrors())
}

extension [String] {
    func joinErrors() -> String { // todo reuse in config parsing?
        map { error in
            error.split(separator: "\n").withIndex
                .map { (i, line) in
                    i == 0
                        ? "ERROR: " + line
                        : "       " + line
                }
                .joined(separator: "\n")
        }
            .joined(separator: "\n")
    }
}

struct Option<T: Copyable> {
    let help: String
    let parser: any ArgParserProtocol<T>

    init(_ help: String, _ parser: any ArgParserProtocol<T>) {
        self.help = help
        self.parser = parser
    }
}

extension [String] {
    mutating func next() -> String {
        nextOrNil() ?? errorT("args is empty")
    }

    mutating func nextOrNil() -> String? {
        let result = first
        self = Array(dropFirst())
        return result
    }
}

private extension ArgParserProtocol {
    func transformRaw(_ raw: T, _ arg: String, _ args: inout [String], _ errors: inout [String]) -> T {
        if raw[keyPath: keyPath] != nil {
            errors.append("Duplicated argument '\(arg)'")
        }
        return raw.copy(keyPath, parse(arg, &args).getOrNil(appendErrorTo: &errors))
    }
}

protocol ArgParserProtocol<T> {
    associatedtype K
    associatedtype T where T : Copyable
    var keyPath: WritableKeyPath<T, K?> { get }
    var parse: (/*arg*/ String, /*nextArgs*/ inout [String]) -> Parsed<K> { get }
}

struct ArgParser<T: Copyable, K>: ArgParserProtocol {
    let keyPath: WritableKeyPath<T, K?>
    let parse: (String, inout [String]) -> Parsed<K>

    init(_ keyPath: WritableKeyPath<T, K?>, _ parse: @escaping (String, inout [String]) -> Parsed<K>) {
        self.keyPath = keyPath
        self.parse = parse
    }

    init(_ keyPath: WritableKeyPath<T, K?>, _ parse: @escaping () -> Parsed<K>) {
        self.init(keyPath, { arg, nextArgs in parse() })
    }

    init(_ keyPath: WritableKeyPath<T, K?>, _ parse: @escaping (inout [String]) -> Parsed<K>) {
        self.init(keyPath, { arg, nextArgs in parse(&nextArgs) })
    }

    init(_ keyPath: WritableKeyPath<T, K?>, _ parse: @escaping (String) -> Parsed<K>) {
        self.init(keyPath, { arg, nextArgs in parse(arg) })
    }
}

func trueBoolFlag<T: Copyable>(_ keyPath: WritableKeyPath<T, Bool?>) -> ArgParser<T, Bool> {
    ArgParser(keyPath) { .success(true) }
}
