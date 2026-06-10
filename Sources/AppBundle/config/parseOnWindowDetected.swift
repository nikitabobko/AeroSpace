import Common

struct WindowDetectedCallback: ConvenienceCopyable, Equatable {
    var matcher: WindowDetectedCallbackMatcher = .command(TrueCommand.instance)
    var checkFurtherCallbacks: Bool = false
    var rawRun: [any Command]? = nil

    var run: [any Command] {
        rawRun ?? dieT("ID-46D063B2 should have discarded nil")
    }

    var debugJson: Json {
        var result: [String: Json] = [:]
        result["matcher"] = switch matcher {
            case .command(let command): .string(command.args.description)
            case .legacy(let legacy): legacy.debugJson
        }
        if let commands = rawRun {
            result["commands"] = .string(commands.prettyDescription)
        }
        return .dict(result)
    }

    static func == (lhs: WindowDetectedCallback, rhs: WindowDetectedCallback) -> Bool {
        lhs.matcher == rhs.matcher && lhs.checkFurtherCallbacks == rhs.checkFurtherCallbacks &&
            zip(lhs.run, rhs.run).allSatisfy { $0.equals($1) }
    }
}

struct LegacyWindowDetectedCallbackMatcher: ConvenienceCopyable, Equatable {
    var appId: String?
    var appNameRegexSubstring: CaseInsensitiveRegex?
    var windowTitleRegexSubstring: CaseInsensitiveRegex?
    var workspace: String?
    var duringAeroSpaceStartup: Bool?

    var debugJson: Json {
        var resultParts: [String] = []
        if let appId {
            resultParts.append("appId=\"\(appId)\"")
        }
        if let appNameRegexSubstring {
            resultParts.append("appNameRegexSubstring=\"\(appNameRegexSubstring.origin)\"")
        }
        if let windowTitleRegexSubstring {
            resultParts.append("windowTitleRegexSubstring=\"\(windowTitleRegexSubstring.origin)\"")
        }
        if let workspace {
            resultParts.append("workspace=\"\(workspace)\"")
        }
        if let duringAeroSpaceStartup {
            resultParts.append("duringAeroSpaceStartup=\(duringAeroSpaceStartup)")
        }
        return .string(resultParts.joined(separator: ", "))
    }
}

enum WindowDetectedCallbackMatcher: Equatable {
    case command(any Command)
    case legacy(LegacyWindowDetectedCallbackMatcher)

    static func == (lhs: WindowDetectedCallbackMatcher, rhs: WindowDetectedCallbackMatcher) -> Bool {
        switch (lhs, rhs) {
            case (.command(let command1), .command(let command2)): command1.equals(command2)
            case (.legacy(let matcher1), .legacy(let matcher2)): matcher1 == matcher2
            default: false
        }
    }
}

private let windowDetectedParser: [String: any ParserProtocol<WindowDetectedCallback>] = [
    "if": Parser(\.matcher, parseMatcher),
    "check-further-callbacks": Parser(\.checkFurtherCallbacks, parseBool),
    "run": Parser(\.rawRun, upcast { parseCommandOrCommands($0).toParsedConfig($1) }),
]

private let matcherParsers: [String: any ParserProtocol<LegacyWindowDetectedCallbackMatcher>] = [
    "app-id": Parser(\.appId, upcast(parseString)),
    "workspace": Parser(\.workspace, upcast(parseString)),
    "app-name-regex-substring": Parser(\.appNameRegexSubstring, upcast(parseCasInsensitiveRegex)),
    "window-title-regex-substring": Parser(\.windowTitleRegexSubstring, upcast(parseCasInsensitiveRegex)),
    "during-aerospace-startup": Parser(\.duringAeroSpaceStartup, upcast(parseBool)),
]

private func upcast<T>(
    _ fun: @escaping @Sendable (OrderedJson, ConfigBacktrace) -> ParsedConfig<T>,
) -> @Sendable (OrderedJson, ConfigBacktrace) -> ParsedConfig<T?> {
    { fun($0, $1).map(Optional.init) }
}

func parseOnWindowDetectedArray(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseDiagnostic]) -> [WindowDetectedCallback] {
    if let array = raw.asArrayOrNil {
        return array.enumerated().map { (index, raw) in parseWindowDetectedCallback(raw, backtrace + .index(index), &errors) }.filterNotNil()
    } else {
        errors += [expectedActualTypeDiagnostic(expected: .array, actual: raw.tomlType, backtrace)]
        return []
    }
}

private func parseCasInsensitiveRegex(_ raw: OrderedJson, _ backtrace: ConfigBacktrace) -> ParsedConfig<CaseInsensitiveRegex> {
    parseString(raw, backtrace).flatMap { CaseInsensitiveRegex.new($0).toParsedConfig(backtrace) }
}

private func parseMatcher(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseDiagnostic]) -> WindowDetectedCallbackMatcher {
    switch raw {
        case .dict(let raw):
            return .legacy(raw.parseTable(LegacyWindowDetectedCallbackMatcher(), matcherParsers, backtrace, &errors))
        case .string(let raw):
            return .command(parseCommand(raw).toEither().toParsedConfig(backtrace).getOrNil(appendErrorTo: &errors) ?? TrueCommand.instance)
        default:
            // Intentionally skip Table type from the list of expected types
            errors.append(.init(backtrace, expectedActualTypeError(expected: .string, actual: raw.tomlType)))
            return .command(TrueCommand.instance)
    }
}

private func parseWindowDetectedCallback(_ raw: OrderedJson, _ backtrace: ConfigBacktrace, _ errors: inout [ConfigParseDiagnostic]) -> WindowDetectedCallback? {
    var myErrors: [ConfigParseDiagnostic] = []
    let callback = parseTable(raw, WindowDetectedCallback(), windowDetectedParser, backtrace, &myErrors)

    if callback.rawRun == nil { // ID-46D063B2
        myErrors.append(.init(backtrace, "'run' is mandatory key"))
    }

    if !myErrors.isEmpty {
        errors += myErrors
        return nil
    }

    return callback
}
