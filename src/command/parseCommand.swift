import TOMLKit

typealias ParsedCommand<T> = Result<T, String>
extension String: Error {}

func parseCommand(_ raw: TOMLValueConvertible) -> ParsedCommand<Command> {
    if let rawString = raw.string {
        return parseSingleCommand(rawString)
    } else if let rawArray = raw.array {
        let commands: ParsedCommand<[Command]> = (0..<rawArray.count).mapAllOrFailure { index in
            let rawString: String = rawArray[index].string ?? expectedActualTypeError(expected: .string, actual: rawArray[index].type)
            return parseSingleCommand(rawString)
        }
        return commands.map { CompositeCommand(subCommands: $0) }
    } else {
        return .failure(expectedActualTypeError(expected: [.string, .array], actual: raw.type))
    }
}

private func parseSingleCommand(_ raw: String) -> ParsedCommand<Command> {
    let words = raw.split(separator: " ")
    let args = words[1...].map { String($0) }
    let firstWord = String(words.first ?? "")
    if firstWord == "workspace" {
        return parseSingleArg(args, firstWord).map { WorkspaceCommand(workspaceName: $0) }
    } else if firstWord == "move-container-to-workspace" {
        return parseSingleArg(args, firstWord).map { MoveContainerToWorkspaceCommand(targetWorkspaceName: $0) }
    } else if firstWord == "mode" {
        return parseSingleArg(args, firstWord).map { ModeCommand(idToActivate: $0) }
    } else if firstWord == "move-in" {
        return parseSingleArg(args, firstWord)
            .flatMap { CardinalDirection(rawValue: $0).orFailure("Can't parse '\(firstWord)' direction") }
            .map { MoveInCommand(direction: $0) }
    } else if firstWord == "move-workspace-to-display" {
        return parseSingleArg(args, firstWord)
            .flatMap { MoveWorkspaceToDisplayCommand.DisplayTarget(rawValue: $0).orFailure("Can't parse '\(firstWord)' display target") }
            .map { MoveWorkspaceToDisplayCommand(displayTarget: $0) }
    } else if firstWord == "resize" {
        let arg1 = args.getOrNil(atIndex: 0).orFailure("''\(firstWord)' must have two parameters")
            .flatMap { ResizeCommand.Dimension(rawValue: String($0)).orFailure("Can't parse '\(firstWord)' first arg") }
        let arg2 = args.getOrNil(atIndex: 1).orFailure("''\(firstWord)' must have two parameters")
            .flatMap { Int($0).orFailure("Can't parse '\(firstWord)' second arg") }
        return arg1.flatMap { arg1 in
            arg2.map { arg2 in
                ResizeCommand(dimension: arg1, diff: arg2)
            }
        }
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
        return args.mapAllOrFailure { parseLayout(String($0)) }
            .flatMap {
                (LayoutCommand(toggleBetween: $0) as Command?).orFailure("Can't create layout command") // todo nicer message
            }
    } else if raw == "workspace-back-and-forth" {
        return .success(WorkspaceBackAndForthCommand())
    } else if raw == "reload-config" {
        return .success(ReloadConfigCommand())
    } else if raw == "flatten-workspace-tree" {
        return .success(FlattenWorkspaceTreeCommand())
    } else if raw == "close-all-windows-but-current" {
        return .success(CloseAllWindowsButCurrentCommand())
    } else if raw == "" {
        return .failure("Can't parse empty string command")
    } else {
        return .failure("Unrecognized command '\(raw)'")
    }
}

func parseLayout(_ raw: String) -> ParsedCommand<ConfigLayout> {
    ConfigLayout(rawValue: raw).orFailure("Can't parse layout '\(raw)'")
}

private func parseSingleArg(_ args: [String], _ command: String) -> ParsedCommand<String> {
    args.singleOrNil().orFailure {
        "\(command) must have only a single argument. But passed: '\(args.joined(separator: " "))'"
    }
}

private func expectedActualTypeError(expected: TOMLType, actual: TOMLType) -> String {
    "Expected type is '\(expected)'. But actual type is '\(actual)'"
}

private func expectedActualTypeError(expected: [TOMLType], actual: TOMLType) -> String {
    if let single = expected.singleOrNil() {
        return expectedActualTypeError(expected: single, actual: actual)
    } else {
        return "Expected types are \(expected.map { "'\($0.description)'" }.joined(separator: " or ")). But actual type is '\(actual)'"
    }
}
