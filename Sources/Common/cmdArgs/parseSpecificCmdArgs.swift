func parseSpecificCmdArgs<T: CmdArgs>(_ raw: T, _ args: StrArrSlice) -> ParsedCmd<T> {
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
            if let optionParser = T.parser.flags[arg] {
                index += 1
                if !options.insert(arg).inserted {
                    errors.append("Duplicated option \(arg.singleQuoted)")
                }
                raw = optionParser.transformRaw(raw, &index, SubArgParserInput(superArg: arg, index: index, args: args), &errors)
            } else {
                errors.append("Unknown flag \(arg.singleQuoted)")
                break
            }
        } else if let parser = T.parser.positionalArgs.getOrNil(atIndex: posArgumentParserIndex) {
            raw = parser.transformRaw(raw, &index, PosArgParserInput(index: index, args: args), &errors)
            posArgumentParserIndex += 1
        } else {
            errors.append("Unknown argument \(arg.singleQuoted)")
            break
        }
    }

    for arg in T.parser.positionalArgs[posArgumentParserIndex...] {
        if let placeholder = arg.context.argPlaceholderIfMandatory {
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

public struct CmdParsingFailure: Sendable, Equatable {
    public let msg: String
    public let exitCode: Int32

    public init(_ msg: String, _ exitCode: Int32) {
        self.msg = msg
        self.exitCode = exitCode
    }
}

extension ArgParserProtocol where Root: ConvenienceCopyable {
    fileprivate func transformRaw(_ raw: consuming Root, _ index: inout Int, _ input: Input, _ errors: inout [String]) -> Root {
        let parsedCliArgs = parse(input)
        index += parsedCliArgs.advanceBy
        return switch parsedCliArgs.value.getOrNil(appendErrorTo: &errors) {
            case let value?: raw.copy(keyPath, value)
            case nil: raw
        }
    }
}

// Hack to preserve backwards compatibility
private func isResizeNegativeUnitsArg(_ raw: any CmdArgs, arg: String) -> Bool {
    var iter = arg.makeIterator()
    return raw is ResizeCmdArgs && iter.next() == "-" && iter.next()?.isNumber == true
}
