import Common

enum AeroObj {
    case window(Window)
    case workspace(Workspace)
    case app(AbstractApp)
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

enum AeroObjKind: CaseIterable {
    case window, workspace, app, monitor
}

enum PlainInterVar: String, CaseIterable {
    case rightPadding = "right-padding"
    case newline = "newline"
    case tab = "tab"
}

extension [AeroObj] {
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
            if !curCell.isEmpty { line.append(Cell(value: curCell, rightPadding: false)) }
            if !errors.isEmpty { return .failure(errors.joinErrors()) }
            cellTable.append(line)
        }
        let result = cellTable
            .transposed()
            .map { column in
                let columndWidth = column.map { $0.value.count }.max()!
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

enum FormatVar: Equatable {
    case window(WindowFormatVar)
    case workspace(WorkspaceFormatVar)
    case app(AppFormatVar)
    case monitor(MonitorFormatVar)

    enum WindowFormatVar: String, Equatable, CaseIterable {
        case windowId = "window-id"
        case windowTitle = "window-title"
    }

    enum WorkspaceFormatVar: String, Equatable, CaseIterable {
        case workspaceName = "workspace"
    }

    enum AppFormatVar: String, Equatable, CaseIterable {
        case appBundleId = "app-bundle-id"
        case appName = "app-name"
        case appPid = "app-pid"
        case appExecPath = "app-exec-path"
        case appBundlePath = "app-bundle-path"
    }

    enum MonitorFormatVar: String, Equatable, CaseIterable {
        case monitorId = "monitor-id"
        case monitorAppKitNsScreenScreensId = "monitor-appkit-nsscreen-screens-id"
        case monitorName = "monitor-name"
    }
}

enum Primitive: Encodable {
    case int(Int)
    case int32(Int32)
    case uint32(UInt32)
    case string(String)

    func toString() -> String {
        switch self {
            case .int(let x): x.description
            case .int32(let x): x.description
            case .uint32(let x): x.description
            case .string(let x): x
        }
    }

    func encode(to encoder: any Encoder) throws {
        let value: Encodable = switch self {
            case .int(let x): x
            case .int32(let x): x
            case .uint32(let x): x
            case .string(let x): x
        }
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

private func getAvailableInterVars(for kind: AeroObjKind) -> [String] {
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

private struct Cell<T> {
    let value: T
    let rightPadding: Bool
}

extension String {
    func expandFormatVar(obj: AeroObj) -> Result<Primitive, String> {
        let formatVar = self.toFormatVar()
        switch (obj, formatVar) {
            case (_, .none): break

            case (.window(let w), .workspace):
                return w.nodeWorkspace.flatMap(AeroObj.workspace).map(expandFormatVar) ?? .success(.string("NULL-WOKRSPACE"))
            case (.window(let w), .monitor):
                return w.nodeMonitor.flatMap(AeroObj.monitor).map(expandFormatVar) ?? .success(.string("NULL-MONITOR"))
            case (.window(let w), .app):
                return expandFormatVar(obj: .app(w.app))
            case (.window(_), .window): break

            case (.workspace(let ws), .monitor):
                return expandFormatVar(obj: AeroObj.monitor(ws.workspaceMonitor))
            case (.workspace, _): break

            case (.app(_), _): break
            case (.monitor(_), _): break
        }
        switch (obj, formatVar) {
            case (.window(let w), .window(let f)):
                return switch f {
                    case .windowId: .success(.uint32(w.windowId))
                    case .windowTitle: .success(.string(w.title))
                }
            case (.workspace(let w), .workspace(let f)):
                return switch f {
                    case .workspaceName: .success(.string(w.name))
                }
            case (.monitor(let m), .monitor(let f)):
                return switch f {
                    case .monitorId: .success(m.monitorId.map { .int($0 + 1) } ?? .string("NULL-MONITOR-ID"))
                    case .monitorAppKitNsScreenScreensId: .success(.int(m.monitorAppKitNsScreenScreensId))
                    case .monitorName: .success(.string(m.name))
                }
            case (.app(let a), .app(let f)):
                return switch f {
                    case .appBundleId: .success(.string(a.id ?? "NULL-APP-BUNDLE-ID"))
                    case .appName: .success(.string(a.name ?? "NULL-APP-NAME"))
                    case .appPid: .success(.int32(a.pid))
                    case .appExecPath: .success(.string(a.execPath ?? "NULL-APP-EXEC-PATH"))
                    case .appBundlePath: .success(.string(a.bundlePath ?? "NULL-APP-BUNDLE-PATH"))
                }
            default: break
        }
        if self == PlainInterVar.newline.rawValue { return .success(.string("\n")) }
        if self == PlainInterVar.tab.rawValue { return .success(.string("\t")) }
        return .failure("Unknown interpolation variable '\(self)'. " +
            "Possible values: \(getAvailableInterVars(for: obj.kind).joined(separator: "|"))")
    }

    private func toFormatVar() -> FormatVar? {
        FormatVar.WindowFormatVar(rawValue: self).flatMap(FormatVar.window)
            ?? FormatVar.WorkspaceFormatVar(rawValue: self).flatMap(FormatVar.workspace)
            ?? FormatVar.AppFormatVar(rawValue: self).flatMap(FormatVar.app)
            ?? FormatVar.MonitorFormatVar(rawValue: self).flatMap(FormatVar.monitor)
    }
}
