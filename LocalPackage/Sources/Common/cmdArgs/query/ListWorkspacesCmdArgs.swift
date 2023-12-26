private let onitors = "<monitors>"

public struct ListWorkspacesCmdArgs: RawCmdArgs, CmdArgs {
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .listWorkspaces,
        allowInConfig: false,
        help: """
              USAGE: list-workspaces [-h|--help] [--visible [no]] [--focused [no]] [--mouse [no]]
                                     [--on-monitors \(onitors)]

              OPTIONS:
                -h, --help                  Print help
                --visible [no]              Filter results to only print currently visible workspaces or not
                --mouse [no]                Filter results to only print the workspace with the mouse or not
                --focused [no]              Filter results to only print the focused workspace or not
                --on-monitors \(onitors)    Filter results to only print the workspaces that are attached to specified monitors.
                                            \(onitors) is a comma separated list of monitor IDs
              """,
        options: [
            "--visible": boolFlag(\.visible),
            "--mouse": boolFlag(\.mouse),
            "--focused": boolFlag(\.focused),
            "--on-monitors": ArgParser(\.onMonitors, parseMonitorIds)
        ],
        arguments: []
    )

    public var visible: Bool?
    public var mouse: Bool?
    public var focused: Bool?
    public var onMonitors: [Int] = []

    public init() {}
}

public func parseListWorkspaces(_ args: [String]) -> ParsedCmd<ListWorkspacesCmdArgs> {
    parseRawCmdArgs(ListWorkspacesCmdArgs(), args)
}

private func parseMonitorIds(arg: String, nextArgs: inout [String]) -> Parsed<[Int]> {
    if let nextArg = nextArgs.nextNonFlagOrNil() {
        var monitors: [Int] = []
        for monitor in nextArg.split(separator: ",").map({ String($0) }) {
            if let unwrapped = Int(monitor) {
                monitors.append(unwrapped - 1)
            } else {
                return .failure("Can't parse '\(monitor)'. It must be a number")
            }
        }
        return .success(monitors)
    } else {
        return .failure("\(onitors) is mandatory")
    }
}
