import AppKit
import Common

struct ServerVersionInternalCommandCommand: Command {
    let args = ServerVersionInternalCommandCmdArgs(rawArgs: [])

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        return state.succCmd(msg: "\(aeroSpaceAppVersion) \(gitHash)")
    }
}
