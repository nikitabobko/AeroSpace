import TOMLKit

typealias Parsed<T> = Result<T, String>
extension String: Error {}

func parseQueryCommand(_ raw: String) -> Parsed<QueryCommand> {
    if raw.contains("'") || raw.contains("\"") {
        return .failure("Quotation marks are reserved for future use")
    } else if raw == "version" || raw == "--version" || raw == "-v" {
        return .success(VersionCommand())
    } else if raw == "list-apps" {
        return .success(ListAppsCommand())
    } else if raw == "" {
        return .failure("Can't parse empty string query command")
    } else {
        return .failure("Unrecognized query command '\(raw)'")
    }
}

func parseCommandOrCommands(_ raw: TOMLValueConvertible) -> Parsed<[Command]> {
    if let rawString = raw.string {
        return parseCommand(rawString).map { [$0] }
    } else if let rawArray = raw.array {
        let commands: Parsed<[Command]> = (0..<rawArray.count).mapAllOrFailure { index in
            let rawString: String = rawArray[index].string ?? expectedActualTypeError(expected: .string, actual: rawArray[index].type)
            return parseCommand(rawString)
        }
        return commands
    } else {
        return .failure(expectedActualTypeError(expected: [.string, .array], actual: raw.type))
    }
}

func parseCommand(_ raw: String) -> Parsed<Command> {
    let words: [String] = raw.split(separator: " ").map { String($0) }
    let args: [String] = Array(words[1...])
    let firstWord = String(words.first ?? "")
    if raw.contains("'") || raw.contains("\"") {
        return .failure("Quotation marks are reserved for future use")
    } else if firstWord == "workspace" {
        return parseSingleArg(args, firstWord).map { WorkspaceCommand(workspaceName: $0) }
    } else if firstWord == "move-node-to-workspace" {
        return parseSingleArg(args, firstWord).map { MoveNodeToWorkspaceCommand(targetWorkspaceName: $0) }
    } else if firstWord == "split" {
        let arg = parseSingleArg(args, firstWord).flatMap {
            SplitCommand.SplitArg(rawValue: $0).orFailure("'\(firstWord)' command: the argument must be (horizontal|vertical|opposite)")
        }
        return arg.map { SplitCommand(splitArg: $0) }
    } else if firstWord == "enable" {
        let arg = parseSingleArg(args, firstWord).flatMap {
            EnableCommand.State(rawValue: $0).orFailure("'\(firstWord)' command: the argument must be (on|off|toggle)")
        }
        return arg.map { EnableCommand(targetState: $0) }
    } else if firstWord == "mode" {
        return parseSingleArg(args, firstWord).map { ModeCommand(idToActivate: $0) }
    } else if firstWord == "join-with" {
        return parseSingleArg(args, firstWord)
            .flatMap { CardinalDirection(rawValue: $0).orFailure("Can't parse '\(firstWord)' direction") }
            .map { JoinWithCommand(direction: $0) }
    } else if firstWord == "move-workspace-to-monitor" || firstWord == "move-workspace-to-display" {
        return parseSingleArg(args, firstWord)
            .flatMap { MoveWorkspaceToMonitorCommand.MonitorTarget(rawValue: $0).orFailure("Can't parse '\(firstWord)' monitor target") }
            .map { MoveWorkspaceToMonitorCommand(monitorTarget: $0) }
    } else if firstWord == "resize" {
        return parseResizeCommand(firstWord: firstWord, args: args)
    } else if firstWord == "exec-and-wait" {
        return .success(ExecAndWaitCommand(bashCommand: raw.removePrefix(firstWord)))
    } else if firstWord == "exec-and-forget" {
        return .success(ExecAndForgetCommand(bashCommand: raw.removePrefix(firstWord)))
    } else if firstWord == "focus" {
        return parseSingleArg(args, firstWord)
            .flatMap { CardinalDirection(rawValue: $0).orFailure("Can't parse '\(firstWord)' direction") }
            .map { FocusCommand(direction: $0) }
    } else if firstWord == "move-through" {
        return parseSingleArg(args, firstWord)
            .flatMap { CardinalDirection(rawValue: $0).orFailure("Can't parse '\(firstWord)' direction") }
            .map { MoveThroughCommand(direction: $0) }
    } else if firstWord == "layout" {
        return args.mapAllOrFailure { $0.parseLayoutDescription().orFailure("Can't parse layout description '\($0)'") }
            .flatMap {
                (LayoutCommand(toggleBetween: $0) as Command?)
                    .orFailure("'\(firstWord)' command must have at least one argument")
            }
    } else if raw == "workspace-back-and-forth" {
        return .success(WorkspaceBackAndForthCommand())
    } else if raw == "fullscreen" {
        return .success(FullscreenCommand())
    } else if raw == "reload-config" {
        return .success(ReloadConfigCommand())
    } else if raw == "flatten-workspace-tree" {
        return .success(FlattenWorkspaceTreeCommand())
    } else if raw == "close-all-windows-but-current" {
        return .success(CloseAllWindowsButCurrentCommand())
    } else if raw == "" {
        return .failure("Can't parse empty string action command")
    } else {
        return .failure("Unrecognized action command '\(raw)'")
    }
}

private func parseResizeCommand(firstWord: String, args: [String]) -> Parsed<Command> {
    let mustHaveTwoArgsMessage = "''\(firstWord)' command must have two parameters"
    let dimension = args.getOrNil(atIndex: 0).orFailure(mustHaveTwoArgsMessage)
        .flatMap { ResizeCommand.Dimension(rawValue: String($0)).orFailure("Can't parse '\(firstWord)' first arg") }
    let secondArg: Result<String, String> = args.getOrNil(atIndex: 1).orFailure(mustHaveTwoArgsMessage)
    let mode = secondArg.map { (secondArg: String) in
        if secondArg.starts(with: "+") {
            return ResizeCommand.ResizeMode.add
        } else if secondArg.starts(with: "-") {
            return ResizeCommand.ResizeMode.subtract
        } else {
            return ResizeCommand.ResizeMode.set
        }
    }
    let unit = secondArg.flatMap {
        UInt($0.removePrefix("+").removePrefix("-"))
            .orFailure("'\(firstWord)' command: Second arg must be a number")
    }
    return dimension.flatMap { dimension in
        mode.flatMap { mode in
            unit.map { unit in
                ResizeCommand(dimension: dimension, mode: mode, unit: unit)
            }
        }
    }
}

private func parseSingleArg(_ args: [String], _ command: String) -> Parsed<String> {
    args.singleOrNil().orFailure {
        "\(command) must have only a single argument. But passed: '\(args.joined(separator: " "))' (\(args.count) args)"
    }
}

func expectedActualTypeError(expected: TOMLType, actual: TOMLType) -> String {
    "Expected type is '\(expected)'. But actual type is '\(actual)'"
}

func expectedActualTypeError(expected: [TOMLType], actual: TOMLType) -> String {
    if let single = expected.singleOrNil() {
        return expectedActualTypeError(expected: single, actual: actual)
    } else {
        return "Expected types are \(expected.map { "'\($0.description)'" }.joined(separator: " or ")). But actual type is '\(actual)'"
    }
}
