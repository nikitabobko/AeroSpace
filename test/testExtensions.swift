@testable import AeroSpace_Debug
import Common
import Foundation
import TOMLKit

extension WindowDetectedCallback: Equatable {
    public static func == (lhs: WindowDetectedCallback, rhs: WindowDetectedCallback) -> Bool {
        check(
            lhs.matcher.appNameRegexSubstring == nil &&
                lhs.matcher.windowTitleRegexSubstring == nil &&
                rhs.matcher.appNameRegexSubstring == nil &&
                rhs.matcher.windowTitleRegexSubstring == nil
        )
        return lhs.matcher.appId == rhs.matcher.appId &&
            lhs.run.map(\.describe) == rhs.run.map(\.describe)
    }
}

extension [TomlParseError] {
    var descriptions: [String] { map(\.description) }
}

extension Mode: Equatable {
    public static func == (lhs: Mode, rhs: Mode) -> Bool {
        lhs.name == rhs.name && lhs.bindings == rhs.bindings
    }
}

extension HotkeyBinding: Equatable {
    public static func == (lhs: HotkeyBinding, rhs: HotkeyBinding) -> Bool {
        lhs.modifiers == rhs.modifiers && lhs.key == rhs.key && lhs.commands.map(\.describe) == rhs.commands.map(\.describe)
    }
}

extension MonitorDescription: Equatable {
    public static func == (lhs: MonitorDescription, rhs: MonitorDescription) -> Bool {
        switch (lhs, rhs) {
        case (.sequenceNumber(let a), .sequenceNumber(let b)):
            return a == b
        case (.main, .main):
            return true
        case (.secondary, .secondary):
            return true
        case (.pattern, .pattern):
            return true
        default:
            return false
        }
    }
}

extension DynamicConfigValue: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.constant(let lhsConstant), .constant(let rhsConstant)):
            return lhsConstant == rhsConstant
        case (.perMonitor(let lhsMonitors, let lhsDefaultValue), .perMonitor(let rhsMonitors, let rhsDefaultValue)):
            return lhsDefaultValue == rhsDefaultValue
                && lhsMonitors.count == rhsMonitors.count
                && zip(lhsMonitors, rhsMonitors).allSatisfy { $0.description == $1.description && $0.value == $1.value }
        default:
            return false
        }
    }
}

extension Gaps: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.outer == rhs.outer && lhs.inner == rhs.inner
    }
}

extension Gaps.Outer: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.left == rhs.left && lhs.right == rhs.right &&
            lhs.bottom == rhs.bottom && lhs.top == rhs.top
    }
}

extension Gaps.Inner: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.horizontal == rhs.horizontal && lhs.vertical == rhs.vertical
    }
}

extension Command {
    var describe: CommandDescription {
        if let focus = self as? FocusCommand {
            return .focusCommand(args: focus.args)
        } else if let resize = self as? ResizeCommand {
            return .resizeCommand(args: resize.args)
        } else if let layout = self as? LayoutCommand {
            return .layoutCommand(args: layout.args)
        } else if let exec = self as? ExecAndForgetCommand {
            return .execAndForget(exec.args.bashScript)
        } else if let moveNodeToWorkspace = self as? MoveNodeToWorkspaceCommand {
            return .moveNodeToWorkspace(args: moveNodeToWorkspace.args)
        } else if let listMonitors = self as? ListMonitorsCommand {
            return .listMonitors(args: listMonitors.args)
        } else if let workspace = self as? WorkspaceCommand {
            return .workspace(args: workspace.args)
        }
        error("Unsupported command: \(self)")
    }
}

enum CommandDescription: Equatable { // todo do I need this class after CmdArgs introduction?
    case focusCommand(args: FocusCmdArgs)
    case resizeCommand(args: ResizeCmdArgs)
    case layoutCommand(args: LayoutCmdArgs)
    case execAndForget(String)
    case moveNodeToWorkspace(args: MoveNodeToWorkspaceCmdArgs)
    case workspace(args: WorkspaceCmdArgs)
    case listMonitors(args: ListMonitorsCmdArgs)
}
