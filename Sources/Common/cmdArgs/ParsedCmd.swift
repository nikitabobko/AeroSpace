public enum ParsedCmd<T: Sendable>: Sendable {
    case cmd(T)
    case help(String)
    case failure(CmdParsingFailure)

    public static func failure(_ msg: String, _ exitCode: Int32) -> Self { .failure(CmdParsingFailure(msg, exitCode)) }

    public func map<R>(_ mapper: (T) -> R) -> ParsedCmd<R> {
        flatMap { .cmd(mapper($0)) }
    }

    public func flatMap<R>(_ mapper: (T) -> ParsedCmd<R>) -> ParsedCmd<R> {
        return switch self {
            case .cmd(let cmd): mapper(cmd)
            case .help(let help): .help(help)
            case .failure(let fail): .failure(fail)
        }
    }

    public var cmdOrNil: T? {
        switch self {
            case .cmd(let t): t
            default: nil
        }
    }
}

extension ParsedCmd where T: CmdArgs {
    public func filter(_ msg: @autoclosure () -> String, _ predicate: (T) -> Bool) -> ParsedCmd<T> {
        flatMap { this in predicate(this) ? .cmd(this) : .failure(msg()) }
    }

    public func filterNot(_ msg: @autoclosure () -> String, _ predicate: (T) -> Bool) -> ParsedCmd<T> {
        flatMap { this in !predicate(this) ? .cmd(this) : .failure(msg()) }
    }

    public static func failure(_ msg: String) -> Self { .failure(CmdParsingFailure(msg, T.ExitCodeType.fail.rawValue)) }
}
