func parseSpecificCmdArgs<T: CmdArgs>(_ raw: T, _ args: StrArrSlice) -> ParsedCmd<T> {
    var raw = raw
    var args = args
    var errors: [String] = []

    var posArgumentParserIndex = 0
    var options: Set<String> = Set()
    var index = 0
    var positionalOnly = false

    loop: while index < args.count {
        let arg = args[index]

        switch (positionalOnly, arg) {
            case (false, "-h"), (false, "--help"):
                return .help(T.info.help)
            case (false, _) where arg.isCliDashFlag && !isResizeNegativeUnitsArg(raw, arg: arg):
                let (flag, inlineValue) = splitGnuStyleInlineValue(arg)
                if let optionParser = T.parser.flags[flag] {
                    if let inlineValue { // GNU style. '--flag=value' is equivalent to '--flag value'
                        args = (args.slice(..<index).orDie() + [flag, inlineValue] + args.slice((index + 1)...).orDie()).slice
                    }
                    index += 1
                    if !options.insert(flag).inserted {
                        errors.append("Duplicated option \(flag.singleQuoted)")
                    }
                    let inlineValueIndex = index
                    raw = optionParser.transformRaw(raw, &index, SubArgParserInput(superArg: flag, index: index, args: args), &errors)
                    if let inlineValue, index == inlineValueIndex {
                        errors.append("Option \(flag.singleQuoted) doesn't accept value \(inlineValue.singleQuoted)")
                        break loop
                    }
                } else {
                    errors.append("Unknown flag \(arg.singleQuoted)")
                    break loop
                }
            default:
                if arg == "--" {
                    positionalOnly = true
                }
                if let parser = T.parser.positionalArgs.getOrNil(atIndex: posArgumentParserIndex) {
                    let input = PosArgParserInput(index: index, args: args, sawDashDash: positionalOnly)
                    raw = parser.transformRaw(raw, &index, input, &errors)
                    posArgumentParserIndex += 1
                } else {
                    errors.append("Unknown argument \(arg.singleQuoted)")
                    break loop
                }
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

extension ArgParserProtocol where Root: ConvenienceMutable {
    fileprivate func transformRaw(_ raw: consuming Root, _ index: inout Int, _ input: Input, _ errors: inout [String]) -> Root {
        let parsedCliArgs = parse(input)
        index += parsedCliArgs.advanceBy
        return switch parsedCliArgs.value.getOrNil(appendErrorTo: &errors) {
            case let value?: raw.copy(keyPath, value)
            case nil: raw
        }
    }
}

/// '--flag=value' -> ('--flag', 'value')
private func splitGnuStyleInlineValue(_ arg: String) -> (flag: String, inlineValue: String?) {
    if arg.starts(with: "--"), let equalsIndex = arg.firstIndex(of: "=") {
        (String(arg[..<equalsIndex]), String(arg[arg.index(after: equalsIndex)...]))
    } else {
        (arg, nil)
    }
}

private func isResizeNegativeUnitsArg(_ raw: any CmdArgs, arg: String) -> Bool {
    var iter = arg.makeIterator()
    return raw is ResizeCmdArgs && iter.next() == "-" && iter.next()?.isNumber == true
}
