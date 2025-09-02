import Common
import TOMLKit

struct WindowDetectedCallback: ConvenienceCopyable, Equatable {
    var matcher: WindowDetectedCallbackMatcher = WindowDetectedCallbackMatcher()
    var checkFurtherCallbacks: Bool = false
    var rawRun: [any Command]? = nil

    var run: [any Command] {
        rawRun ?? dieT("ID-46D063B2 should have discarded nil")
    }

    var debugJson: Json {
        var result: [String: Json] = [:]
        result["matcher"] = matcher.debugJson
        if let commands = rawRun {
            result["commands"] = .string(commands.prettyDescription)
        }
        return .dict(result)
    }

    static func == (lhs: WindowDetectedCallback, rhs: WindowDetectedCallback) -> Bool {
        return lhs.matcher == rhs.matcher && lhs.checkFurtherCallbacks == rhs.checkFurtherCallbacks &&
            zip(lhs.run, rhs.run).allSatisfy { $0.equals($1) }
    }
}

struct WindowDetectedCallbackMatcher: ConvenienceCopyable, Equatable {
    var appIds: [String]?
    var appNameRegexSubstring: Regex<AnyRegexOutput>?
    var windowTitleRegexSubstring: Regex<AnyRegexOutput>?
    var workspace: String?
    var duringAeroSpaceStartup: Bool?

    // Backward compatibility - computed property for single appId
    var appId: String? {
        get { appIds?.first }
        set { appIds = newValue.map { [$0] } }
    }

    // Default initializer with new appIds parameter
    init(
        appIds: [String]? = nil,
        appNameRegexSubstring: Regex<AnyRegexOutput>? = nil,
        windowTitleRegexSubstring: Regex<AnyRegexOutput>? = nil,
        workspace: String? = nil,
        duringAeroSpaceStartup: Bool? = nil
    ) {
        self.appIds = appIds
        self.appNameRegexSubstring = appNameRegexSubstring
        self.windowTitleRegexSubstring = windowTitleRegexSubstring
        self.workspace = workspace
        self.duringAeroSpaceStartup = duringAeroSpaceStartup
    }

    // Backward compatibility initializer with old appId parameter
    init(
        appId: String?,
        appNameRegexSubstring: Regex<AnyRegexOutput>? = nil,
        windowTitleRegexSubstring: Regex<AnyRegexOutput>? = nil,
        workspace: String? = nil,
        duringAeroSpaceStartup: Bool? = nil
    ) {
        self.appIds = appId.map { [$0] }
        self.appNameRegexSubstring = appNameRegexSubstring
        self.windowTitleRegexSubstring = windowTitleRegexSubstring
        self.workspace = workspace
        self.duringAeroSpaceStartup = duringAeroSpaceStartup
    }

    var debugJson: Json {
        var resultParts: [String] = []
        if let appIds {
            if appIds.count == 1 {
                resultParts.append("appId=\"\(appIds[0])\"")
            } else {
                resultParts.append("appIds=\(appIds)")
            }
        }
        if appNameRegexSubstring != nil {
            resultParts.append("appNameRegexSubstrin=Regex")
        }
        if windowTitleRegexSubstring != nil {
            resultParts.append("windowTitleRegexSubstring=Regex")
        }
        if let workspace {
            resultParts.append("workspace=\"\(workspace)\"")
        }
        if let duringAeroSpaceStartup {
            resultParts.append("duringAeroSpaceStartup=\(duringAeroSpaceStartup)")
        }
        return .string(resultParts.joined(separator: ", "))
    }

    static func == (lhs: WindowDetectedCallbackMatcher, rhs: WindowDetectedCallbackMatcher) -> Bool {
        check(
            lhs.appNameRegexSubstring == nil &&
                lhs.windowTitleRegexSubstring == nil &&
                rhs.appNameRegexSubstring == nil &&
                rhs.windowTitleRegexSubstring == nil,
        )
        return lhs.appIds == rhs.appIds
    }
}

private let windowDetectedParser: [String: any ParserProtocol<WindowDetectedCallback>] = [
    "if": Parser(\.matcher, parseMatcher),
    "check-further-callbacks": Parser(\.checkFurtherCallbacks, parseBool),
    "run": Parser(\.rawRun, upcast { parseCommandOrCommands($0).toParsedToml($1) }),
]

private let matcherParsers: [String: any ParserProtocol<WindowDetectedCallbackMatcher>] = [
    "app-id": Parser(\.appIds, upcast(parseAppIds)),
    "workspace": Parser(\.workspace, upcast(parseString)),
    "app-name-regex-substring": Parser(\.appNameRegexSubstring, upcast(parseCasInsensitiveRegex)),
    "window-title-regex-substring": Parser(\.windowTitleRegexSubstring, upcast(parseCasInsensitiveRegex)),
    "during-aerospace-startup": Parser(\.duringAeroSpaceStartup, upcast(parseBool)),
]

private func upcast<T>(_ fun: @escaping @Sendable (TOMLValueConvertible, TomlBacktrace) -> ParsedToml<T>) -> @Sendable (TOMLValueConvertible, TomlBacktrace) -> ParsedToml<T?> {
    { fun($0, $1).map { $0 } }
}

func parseOnWindowDetectedArray(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [WindowDetectedCallback] {
    if let array = raw.array {
        return array.enumerated().map { (index, raw) in parseWindowDetectedCallback(raw, backtrace + .index(index), &errors) }.filterNotNil()
    } else {
        errors += [expectedActualTypeError(expected: .array, actual: raw.type, backtrace)]
        return []
    }
}

private func parseCasInsensitiveRegex(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Regex<AnyRegexOutput>> {
    parseString(raw, backtrace).flatMap { parseCaseInsensitiveRegex($0).toParsedToml(backtrace) }
}

private func parseMatcher(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> WindowDetectedCallbackMatcher {
    parseTable(raw, WindowDetectedCallbackMatcher(), matcherParsers, backtrace, &errors)
}

private func parseWindowDetectedCallback(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> WindowDetectedCallback? {
    var myErrors: [TomlParseError] = []
    let callback = parseTable(raw, WindowDetectedCallback(), windowDetectedParser, backtrace, &myErrors)

    if callback.rawRun == nil { // ID-46D063B2
        myErrors.append(.semantic(backtrace, "'run' is mandatory key"))
    }

    let run = callback.rawRun ?? []

    // - 'exec' is prohibited because command-subject isn't yet supported in "exec session"
    // - Commands that change focus are prohibited because the design isn't yet clear
    if !run.allSatisfy({
        let layoutArg = ($0 as? LayoutCommand)?.args.toggleBetween.val.singleOrNil()
        return layoutArg == .floating || layoutArg == .tiling || $0 is MoveNodeToWorkspaceCommand
    }) {
        myErrors.append(.semantic(
            backtrace,
            "For now, 'layout floating', 'layout tiling' and 'move-node-to-workspace' are the only commands that are supported in 'on-window-detected'. " +
                "Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20",
        ))
    }

    let count = run.count(where: { $0 is MoveNodeToWorkspaceCommand })
    if count >= 1 && !(run.last is MoveNodeToWorkspaceCommand) {
        myErrors.append(.semantic(
            backtrace,
            "For now, 'move-node-to-workspace' must be the latest instruction in the callback (otherwise it's error-prone). " +
                "Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20",
        ))
    }

    if count > 1 {
        myErrors.append(.semantic(
            backtrace,
            "For now, 'move-node-to-workspace' can be mentioned only once in 'run' callback. " +
                "Please report your use cases to https://github.com/nikitabobko/AeroSpace/issues/20",
        ))
    }

    if !myErrors.isEmpty {
        errors += myErrors
        return nil
    }

    return callback
}
