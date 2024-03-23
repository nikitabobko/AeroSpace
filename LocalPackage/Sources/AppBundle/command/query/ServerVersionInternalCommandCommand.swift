import AppKit
import Common

struct ServerVersionInternalCommandCommand: Command {
    let args = ServerVersionInternalCommandCmdArgs()

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        state.stdout.append("\(Bundle.appVersion) \(gitHash)")
        return true
    }
}
