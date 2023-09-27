import TOMLKit

// todo drop TomlBacktrace
func parseCommand(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> Command {
    if let rawString = raw.string {
        return parseSingleCommand(rawString, backtrace)
    } else if let rawArray = raw.array {
        let commands: [Command] = (0..<rawArray.count).map { index in
            let indexBacktrace = backtrace + .index(index)
            let rawString: String = rawArray[index].string ??
                expectedActualTypeError(expected: .string, actual: rawArray[index].type, indexBacktrace)
            return parseSingleCommand(rawString, indexBacktrace)
        }
        return CompositeCommand(subCommands: commands)
    } else {
        return expectedActualTypeError(expected: [.string, .array], actual: raw.type, backtrace)
    }
}

private func parseSingleCommand(_ raw: String, _ backtrace: TomlBacktrace) -> Command {
    let words = raw.split(separator: " ")
    let args = words[1...]
    let firstWord = String(words.first ?? "")
    if firstWord == "workspace" {
        return WorkspaceCommand(workspaceName: parseSingleArg(args, firstWord, backtrace))
    } else if firstWord == "move_container_to_workspace" {
        return MoveContainerToWorkspaceCommand(targetWorkspaceName: parseSingleArg(args, firstWord, backtrace))
    } else if firstWord == "mode" {
        return ModeCommand(idToActivate: parseSingleArg(args, firstWord, backtrace))
    } else if firstWord == "exec_and_wait" {
        return ExecAndWaitCommand(bashCommand: raw.removePrefix(firstWord))
    } else if firstWord == "exec_and_forget" {
        return ExecAndForgetCommand(bashCommand: raw.removePrefix(firstWord))
    } else if firstWord == "focus" {
        let direction = FocusCommand.Direction(rawValue: parseSingleArg(args, firstWord, backtrace))
            ?? errorT("\(backtrace): Can't parse '\(firstWord)' direction")
        return FocusCommand(direction: direction)
    } else if firstWord == "move_through" {
        let direction = CardinalDirection(rawValue: parseSingleArg(args, firstWord, backtrace))
            ?? errorT("\(backtrace): Can't parse '\(firstWord)' direction")
        return MoveThroughCommand(direction: direction)
    } else if firstWord == "layout" {
        return LayoutCommand(toggleBetween: args.map { parseLayout(String($0), backtrace) })
            ?? errorT("\(backtrace): Can't create layout command") // todo nicer message
    } else if raw == "workspace_back_and_forth" {
        return WorkspaceBackAndForth()
    } else if raw == "reload_config" {
        return ReloadConfigCommand()
    } else if raw == "flatten_workspace_tree" {
        return FlattenWorkspaceTreeCommand()
    } else if raw == "close_all_windows_but_current" {
        return CloseAllWindowsButCurrentCommand()
    } else if raw == "" {
        error("\(backtrace): Can't parse empty string command")
    } else {
        error("\(backtrace): Can't parse '\(raw)' command")
    }
}

func parseLayout(_ raw: String, _ backtrace: TomlBacktrace) -> ConfigLayout {
    ConfigLayout(rawValue: raw) ?? errorT("\(backtrace): Can't parse layout '\(raw)'")
}

private func parseSingleArg(_ args: ArraySlice<Swift.String.SubSequence>, _ command: String, _ backtrace: TomlBacktrace) -> String {
    args.singleOrNil().flatMap { String($0) } ?? errorT(
        "\(backtrace): \(command) must have only a single argument. But passed: '\(args.joined(separator: " "))'"
    )
}

private func expectedActualTypeError<T>(expected: TOMLType, actual: TOMLType, _ backtrace: TomlBacktrace) -> T {
    error("\(backtrace): Expected type is '\(expected)'. But actual type is '\(actual)'")
}

private func expectedActualTypeError<T>(expected: [TOMLType], actual: TOMLType, _ backtrace: TomlBacktrace) -> T {
    if let single = expected.singleOrNil() {
        return expectedActualTypeError(expected: single, actual: actual, backtrace)
    } else {
        error("\(backtrace): Expected types are \(expected.map { "'\($0.description)'" }.joined(separator: " or ")). But actual type is '\(actual)'")
    }
}
