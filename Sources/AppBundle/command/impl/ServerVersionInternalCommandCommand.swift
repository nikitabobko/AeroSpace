import AppKit
import Common

struct ServerVersionInternalCommandCommand: Command {
    let args = ServerVersionInternalCommandCmdArgs(rawArgs: [])

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)
        return io.out("\(aeroSpaceAppVersion) \(gitHash)")
    }
}
