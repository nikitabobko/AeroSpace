import Common

enum AeroObj {
    case window(window: Window, title: String)
    case workspace(Workspace)
    case app(any AbstractApp)
    case monitor(Monitor)

    var kind: AeroObjKind {
        switch self {
            case .window: .window
            case .workspace: .workspace
            case .app: .app
            case .monitor: .monitor
        }
    }
}

extension [AeroObj] {
    @MainActor
    func format(_ format: [StringInterToken]) -> Result<[String], String> {
        var cellTable: [[Cell<String>]] = []
        for obj in self {
            var line: [Cell<String>] = []
            var curCell: String = ""
            var errors: [String] = []
            for token in format {
                switch token {
                    case .interVar(PlainInterVar.rightPadding.rawValue):
                        line.append(Cell(value: curCell, rightPadding: true))
                        curCell = ""
                    case .literal(let literal):
                        curCell += literal
                    case .interVar(let value):
                        switch value.expandFormatVar(obj: obj) {
                            case .success(let expanded): curCell += expanded.toString()
                            case .failure(let error): errors.append(error)
                        }
                }
            }
            if !errors.isEmpty { return .failure(errors.joinErrors()) }
            line.append(Cell(value: curCell, rightPadding: false))
            cellTable.append(line)
        }
        let result = cellTable
            .transposed()
            .map { column in
                let columndWidth = column.map { $0.value.count }.max().orDie()
                return column.map {
                    $0.rightPadding
                        ? $0.value + String(repeating: " ", count: columndWidth - $0.value.count)
                        : $0.value
                }
            }
            .transposed()
            .map { line in line.joined(separator: "") }
        return .success(result)
    }
}

enum Primitive: Encodable {
    case bool(Bool)
    case int(Int64)
    case string(String)

    enum Kind: String {
        case bool
        case int
        case string
    }

    var kind: Kind {
        switch self {
            case .bool: .bool
            case .int: .int
            case .string: .string
        }
    }

    func toString() -> String {
        switch self {
            case .bool(let x): x.description
            case .int(let x): x.description
            case .string(let x): x
        }
    }

    func encode(to encoder: any Encoder) throws {
        let value: Encodable = switch self {
            case .bool(let x): x
            case .int(let x): x
            case .string(let x): x
        }
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public static func int(_ int: UInt32) -> Self { .int(Int64(exactly: int).orDie()) }
    public static func int(_ int: Int32) -> Self { .int(Int64(exactly: int).orDie()) }
    public static func int(_ int: Int) -> Self { .int(Int64(exactly: int).orDie()) }
}

private struct Cell<T> {
    let value: T
    let rightPadding: Bool
}

extension FormatVar {
    @MainActor func expandFormatVar(obj: AeroObj) -> Result<Primitive, String> {
        switch (obj, self) {
            case (.window(let w, _), .workspace):
                return w.nodeWorkspace.flatMap(AeroObj.workspace).map(expandFormatVar) ?? .success(.string("NULL-WORKSPACE"))
            case (.window(let w, _), .monitor):
                return w.nodeMonitor.flatMap(AeroObj.monitor).map(expandFormatVar) ?? .success(.string("NULL-MONITOR"))
            case (.window(let w, _), .app):
                return expandFormatVar(obj: .app(w.app))
            case (.window(_, _), .window): break

            case (.workspace(let ws), .monitor):
                return expandFormatVar(obj: AeroObj.monitor(ws.workspaceMonitor))
            case (.workspace, _): break

            case (.app(_), _): break
            case (.monitor(_), _): break
        }

        switch (obj, self) {
            case (.window(let w, let title), .window(let f)):
                return switch f {
                    case .windowId: .success(.int(w.windowId))
                    case .windowIsFullscreen: .success(.bool(w.isFullscreen))
                    case .windowTitle: .success(.string(title))
                    case .windowLayout, .windowParentContainerLayout: toLayoutResult(w: w)
                }
            case (.workspace(let w), .workspace(let f)):
                return switch f {
                    case .workspaceName: .success(.string(w.name))
                    case .workspaceVisible: .success(.bool(w.isVisible))
                    case .workspaceFocused: .success(.bool(focus.workspace == w))
                    case .workspaceRootContainerLayout: .success(.string(toLayoutString(tc: w.rootTilingContainer)))
                }
            case (.monitor(let m), .monitor(let f)):
                return switch f {
                    case .monitorId_oneBased: .success(m.monitorId_oneBased.map { .int($0) } ?? .string("NULL-MONITOR-ID"))
                    case .monitorAppKitNsScreenScreensId: .success(.int(m.monitorAppKitNsScreenScreensId))
                    case .monitorName: .success(.string(m.name))
                    case .monitorIsMain: .success(.bool(m.isMain))
                }
            case (.app(let a), .app(let f)):
                return switch f {
                    case .appBundleId: .success(.string(a.rawAppBundleId ?? "NULL-APP-BUNDLE-ID"))
                    case .appName: .success(.string(a.name ?? "NULL-APP-NAME"))
                    case .appPid: .success(.int(a.pid))
                    case .appExecPath: .success(.string(a.execPath ?? "NULL-APP-EXEC-PATH"))
                    case .appBundlePath: .success(.string(a.bundlePath ?? "NULL-APP-BUNDLE-PATH"))
                }
            default: break
        }
        return .failure(unknownInterpolationVariable(variable: rawValue, obj))
    }
}

extension PlainInterVar {
    @MainActor func expandFormatVar() -> Result<Primitive, String> {
        switch self {
            case .newline: .success(.string("\n"))
            case .tab: .success(.string("\t"))
            case .rightPadding:
                .failure("\(PlainInterVar.rightPadding.rawValue.singleQuoted) interpolation variable cannot be expanded")
        }
    }
}

extension String {
    @MainActor func expandFormatVar(obj: AeroObj) -> Result<Primitive, String> {
        if let it = FormatVar(rawValue: self)?.expandFormatVar(obj: obj) {
            return it
        }
        if let it = PlainInterVar(rawValue: self)?.expandFormatVar() {
            return it
        }
        return .failure(unknownInterpolationVariable(variable: self, obj))
    }
}

func unknownInterpolationVariable(variable: String, _ obj: AeroObj) -> String {
    "Unknown interpolation variable '\(variable)'. " +
        "Possible values:\n\(getAvailableInterVars(for: obj.kind).joined(separator: "\n").prependLines("  "))"
}

private func toLayoutString(tc: TilingContainer) -> String {
    switch (tc.layout, tc.orientation) {
        case (.tiles, .h): return LayoutCmdArgs.LayoutDescription.h_tiles.rawValue
        case (.tiles, .v): return LayoutCmdArgs.LayoutDescription.v_tiles.rawValue
        case (.accordion, .h): return LayoutCmdArgs.LayoutDescription.h_accordion.rawValue
        case (.accordion, .v): return LayoutCmdArgs.LayoutDescription.v_accordion.rawValue
    }
}

private func toLayoutResult(w: Window) -> Result<Primitive, String> {
    guard let parent = w.parent else { return .failure("NULL-PARENT") }
    return switch getChildParentRelation(child: w, parent: parent) {
        case .tiling(let tc): .success(.string(toLayoutString(tc: tc)))
        case .floatingWindow: .success(.string(LayoutCmdArgs.LayoutDescription.floating.rawValue))
        case .macosNativeFullscreenWindow: .success(.string("macos_native_fullscreen"))
        case .macosNativeHiddenAppWindow: .success(.string("macos_native_window_of_hidden_app"))
        case .macosNativeMinimizedWindow: .success(.string("macos_native_minimized"))
        case .macosPopupWindow: .success(.string("NULL-WINDOW-LAYOUT"))

        case .rootTilingContainer: .failure("Not possible")
        case .shimContainerRelation: .failure("Window cannot have a shim container relation")
    }
}
