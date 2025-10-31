public func parseSpecificCmdArgs<T: CmdArgs>(_ raw: T, _ args: StrArrSlice) -> ParsedCmd<T> {
    var raw = raw
    var errors: [String] = []

    var posArgumentParserIndex = 0
    var options: Set<String> = Set()
    var index = 0

    while index < args.count {
        let arg = args[index]
        if arg == "-h" || arg == "--help" {
            return .help(T.info.help)
        } else if arg.starts(with: "-") && !isResizeNegativeUnitsArg(raw, arg: arg) {
            if let optionParser: any SubArgParserProtocol<T> = T.parser.flags[arg] {
                index += 1
                if !options.insert(arg).inserted {
                    errors.append("Duplicated option \(arg.singleQuoted)")
                }
                raw = optionParser.transformRaw(raw, superArg: arg, &index, args, &errors)
            } else {
                errors.append("Unknown flag \(arg.singleQuoted)")
                break
            }
        } else if let parser = T.parser.positionalArgs.getOrNil(atIndex: posArgumentParserIndex) {
            raw = parser.transformRaw(raw, &index, args, &errors)
            posArgumentParserIndex += 1
        } else {
            errors.append("Unknown argument \(arg.singleQuoted)")
            break
        }
    }

    for arg in T.parser.positionalArgs[posArgumentParserIndex...] {
        if let placeholder = arg.argPlaceholderIfMandatory {
            errors.append("Argument \(placeholder.singleQuoted) is mandatory")
        }
    }

    for conflictSet in T.parser.conflictingOptions {
        let mutualOptions = conflictSet.intersection(options)
        if mutualOptions.count > 1 {
            errors.append("Conflicting options: \(mutualOptions.sorted().joined(separator: ", "))")
            break
        }
    }

    return errors.isEmpty ? .cmd(raw) : .failure(errors.joinErrors())
}

public enum ParsedCmd<T: Sendable>: Sendable {
    case cmd(T)
    case help(String)
    case failure(String)

    public func map<R>(_ mapper: (T) -> R) -> ParsedCmd<R> {
        flatMap { .cmd(mapper($0)) }
    }

    public func filter(_ msg: @autoclosure () -> String, _ predicate: (T) -> Bool) -> ParsedCmd<T> {
        flatMap { this in predicate(this) ? .cmd(this) : .failure(msg()) }
    }

    public func filterNot(_ msg: @autoclosure () -> String, _ predicate: (T) -> Bool) -> ParsedCmd<T> {
        flatMap { this in !predicate(this) ? .cmd(this) : .failure(msg()) }
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

    public func unwrap() -> (T?, String?, String?) {
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

extension SubArgParserProtocol {
    fileprivate func transformRaw(_ raw: consuming T, superArg: String, _ index: inout Int, _ args: StrArrSlice, _ errors: inout [String]) -> T {
        let input = SubArgParserInput(superArg: superArg, index: index, args: args)
        let parsedCliArgs = parse(input)
        index += parsedCliArgs.advanceBy
        if let value = parsedCliArgs.value.getOrNil(appendErrorTo: &errors) {
            return raw.copy(keyPath, value)
        } else {
            return raw
        }
    }
}

extension ArgParserProtocol {
    fileprivate func transformRaw(_ raw: consuming T, _ index: inout Int, _ args: StrArrSlice, _ errors: inout [String]) -> T {
        let input = ArgParserInput(index: index, args: args)
        let parsedCliArgs = parse(input)
        index += parsedCliArgs.advanceBy
        if let value = parsedCliArgs.value.getOrNil(appendErrorTo: &errors) {
            return raw.copy(keyPath, value)
        } else {
            return raw
        }
    }
}

// Hack to preserve backwards compatibility
private func isResizeNegativeUnitsArg(_ raw: any CmdArgs, arg: String) -> Bool {
    var iter = arg.makeIterator()
    return raw is ResizeCmdArgs && iter.next() == "-" && iter.next()?.isNumber == true
}
