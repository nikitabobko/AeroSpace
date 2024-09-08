import AppKit
import Common

struct ListAppsCommand: Command {
    let args: ListAppsCmdArgs

    func _run(_ state: CommandMutableState, stdin: String) -> Bool {
        check(Thread.current.isMainThread)
        var result = apps
        if let hidden = args.macosHidden {
            result = result.filter { $0.asMacApp().nsApp.isHidden == hidden }
        }
        switch result.map({ AeroObj.app($0) }).format(args.format) {
            case .success(let lines):
                state.stdout += lines
                return true
            case .failure(let msg):
                return state.failCmd(msg: msg)
        }
    }
}
