import OrderedCollections

private let workspace = "<workspace>"
private let workspaces = "\(workspace)..."

public struct ListWindowsCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWindows,
        allowInConfig: false,
        help: list_windows_help_generated,
        flags: [
            "--all": trueBoolFlag(\.all),

            // Filtering flags
            "--focused": trueBoolFlag(\.filteringOptions.focused),
            "--monitor": SubArgParser(\.filteringOptions.monitors, parseMonitorIds),
            "--workspace": SubArgParser(\.filteringOptions.workspaces, parseWorkspaces),
            "--pid": singleValueSubArgParser(\.filteringOptions.pidFilter, "<pid>", Int32.init),
            "--app-bundle-id": singleValueSubArgParser(\.filteringOptions.appIdFilter, "<app-bundle-id>") { $0 },

            // Formatting flags
            "--format": formatParser(\._format, for: .window),
            "--count": trueBoolFlag(\.outputOnlyCount),
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [],
        conflictingOptions: [
            ["--all", "--focused", "--workspace"],
            ["--all", "--focused", "--monitor"],
            ["--count", "--format"],
            ["--count", "--json"],
        ],
    )

    fileprivate var all: Bool = false // ALIAS

    public var filteringOptions = FilteringOptions()
    public var _format: [StringInterToken] = []
    public var outputOnlyCount: Bool = false
    public var json: Bool = false

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?

    public struct FilteringOptions: ConvenienceCopyable, Equatable, Sendable {
        public var monitors: [MonitorId] = []
        public var focused: Bool = false
        public var workspaces: [WorkspaceFilter] = []
        public var pidFilter: Int32?
        public var appIdFilter: String?
    }
}

extension ListWindowsCmdArgs {
    public var format: [StringInterToken] {
        _format.isEmpty
            ? [
                .interVar("window-id"), .interVar("right-padding"), .literal(" | "),
                .interVar("app-name"), .interVar("right-padding"), .literal(" | "),
                .interVar("window-title"),
            ]
            : _format
    }
}

public func parseListWindowsCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ListWindowsCmdArgs> {
    let args = args.map { $0 == "--app-id" ? "--app-bundle-id" : $0 }.slice // Compatibility
    return parseSpecificCmdArgs(ListWindowsCmdArgs(rawArgsForStrRepr: .init(args)), args)
        .filter("Mandatory option is not specified (--focused|--all|--monitor|--workspace)") { raw in
            raw.filteringOptions.focused || raw.all || !raw.filteringOptions.monitors.isEmpty || !raw.filteringOptions.workspaces.isEmpty
        }
        .filter("--all conflicts with \"filtering\" flags. Please use '--monitor all' instead of '--all' alias") { raw in
            raw.all.implies(raw.filteringOptions == ListWindowsCmdArgs.FilteringOptions())
        }
        .filter("--focused conflicts with other \"filtering\" flags") { raw in
            raw.filteringOptions.focused.implies(raw.filteringOptions.copy(\.focused, false) == ListWindowsCmdArgs.FilteringOptions())
        }
        .map { raw in
            raw.all ? raw.copy(\.filteringOptions.monitors, [.all]).copy(\.all, false) : raw // Normalize alias
        }
        .flatMap { if $0.json, let msg = getErrorIfFormatIsIncompatibleWithJson($0._format) { .failure(msg) } else { .cmd($0) } }
}

func formatParser<T: ConvenienceCopyable>(
    _ keyPath: SendableWritableKeyPath<T, [StringInterToken]>,
    for kind: AeroObjKind,
) -> SubArgParser<T, [StringInterToken]> {
    return SubArgParser(keyPath) { input in
        if let arg = input.nonFlagArgOrNil() {
            return switch arg.interpolationTokens(interpolationChar: "%") {
                case .success(let tokens): .succ(tokens, advanceBy: 1)
                case .failure(let err): .fail("Failed to parse <output-format>. \(err)", advanceBy: 1)
            }
        } else {
            let values = getAvailableInterVars(for: kind).joined(separator: "\n").prependLines("  ")
            return .fail("<output-format> is mandatory. Possible values:\n\(values)", advanceBy: 0)
        }
    }
}

private func parseWorkspaces(input: SubArgParserInput) -> ParsedCliArgs<[WorkspaceFilter]> {
    let args = input.nonFlagArgs()
    let possibleValues = "\(workspace) possible values: (<workspace-name>|focused|visible)"
    if args.isEmpty {
        return .fail("\(workspaces) is mandatory. \(possibleValues)", advanceBy: args.count)
    }
    var workspaces: [WorkspaceFilter] = []
    var i = 0
    for workspaceRaw in args {
        switch workspaceRaw {
            case "visible": workspaces.append(.visible)
            case "focused": workspaces.append(.focused)
            default:
                switch WorkspaceName.parse(workspaceRaw) {
                    case .success(let unwrapped): workspaces.append(.name(unwrapped))
                    case .failure(let msg): return .fail(msg, advanceBy: i + 1)
                }
        }
        i += 1
    }
    return .succ(workspaces, advanceBy: workspaces.count)
}

public enum WorkspaceFilter: Equatable, Sendable {
    case focused
    case visible
    case name(WorkspaceName)
}

public enum FormatVar: Equatable {
    case window(WindowFormatVar)
    case workspace(WorkspaceFormatVar)
    case app(AppFormatVar)
    case monitor(MonitorFormatVar)

    public enum WindowFormatVar: String, Equatable, CaseIterable {
        case windowId = "window-id"
        case windowIsFullscreen = "window-is-fullscreen"
        case windowTitle = "window-title"
        case windowLayout = "window-layout" // An alias for windowParentContainerLayout
        case windowParentContainerLayout = "window-parent-container-layout"
    }

    public enum WorkspaceFormatVar: String, Equatable, CaseIterable {
        case workspaceName = "workspace"
        case workspaceFocused = "workspace-is-focused"
        case workspaceVisible = "workspace-is-visible"
        case workspaceRootContainerLayout = "workspace-root-container-layout"
    }

    public enum AppFormatVar: String, Equatable, CaseIterable {
        case appBundleId = "app-bundle-id"
        case appName = "app-name"
        case appPid = "app-pid"
        case appExecPath = "app-exec-path"
        case appBundlePath = "app-bundle-path"
    }

    public enum MonitorFormatVar: String, Equatable, CaseIterable {
        case monitorId = "monitor-id"
        case monitorAppKitNsScreenScreensId = "monitor-appkit-nsscreen-screens-id"
        case monitorName = "monitor-name"
        case monitorIsMain = "monitor-is-main"
    }
}

public enum PlainInterVar: String, CaseIterable {
    case rightPadding = "right-padding"
    case newline = "newline"
    case tab = "tab"
}

public enum AeroObjKind: CaseIterable, Sendable {
    case window, workspace, app, monitor
}

public func getAvailableInterVars(for kind: AeroObjKind) -> [String] {
    _getAvailableInterVars(for: kind) + PlainInterVar.allCases.map(\.rawValue)
}

private func _getAvailableInterVars(for kind: AeroObjKind) -> [String] {
    switch kind {
        case .app: FormatVar.AppFormatVar.allCases.map(\.rawValue)
        case .monitor: FormatVar.MonitorFormatVar.allCases.map(\.rawValue)
        case .workspace:
            FormatVar.WorkspaceFormatVar.allCases.map(\.rawValue) +
                _getAvailableInterVars(for: .monitor)
        case .window:
            FormatVar.WindowFormatVar.allCases.map(\.rawValue) +
                _getAvailableInterVars(for: .workspace) +
                _getAvailableInterVars(for: .app)
    }
}
