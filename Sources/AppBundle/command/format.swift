import Common

enum AeroObj {
    case window(Window)
    case workspace(Workspace)
    case app(AbstractApp)
    case monitor(Monitor)
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
                    case .value("right-padding"):
                        line.append(Cell(value: curCell, rightPadding: true))
                        curCell = ""
                    case .literal(let literal):
                        curCell += literal
                    case .value(let value):
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

private enum FormatVar: Equatable {
    case window(WindowFormatVar)
    case workspace(WorkspaceFormatVar)
    case app(AppFormatVar)
    case monitor(MonitorFormatVar)

    enum WindowFormatVar: String, Equatable {
        case windowId = "window-id"
        case windowTitle = "window-title"
    }

    enum WorkspaceFormatVar: String, Equatable {
        case workspaceName = "workspace"
    }

    enum AppFormatVar: String, Equatable {
        case appBundleId = "app-bundle-id"
        case appName = "app-name"
        case appPid = "app-pid"
    }

    enum MonitorFormatVar: String, Equatable {
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
                return w.workspace.flatMap(AeroObj.workspace).map(expandFormatVar) ?? .success(.string("NULL-WOKRSPACE"))
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
                }
            default: break
        }
        if self == "newline" { return .success(.string("\n")) }
        if self == "tab" { return .success(.string("\t")) }
        return .failure("Unknown interpolation variable '\(self)'")
    }

    private func toFormatVar() -> FormatVar? {
        FormatVar.WindowFormatVar(rawValue: self).flatMap(FormatVar.window)
            ?? FormatVar.WorkspaceFormatVar(rawValue: self).flatMap(FormatVar.workspace)
            ?? FormatVar.AppFormatVar(rawValue: self).flatMap(FormatVar.app)
            ?? FormatVar.MonitorFormatVar(rawValue: self).flatMap(FormatVar.monitor)
    }
}
