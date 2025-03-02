import AppKit
import Common

struct ServerVersionInternalCommandCommand: Command {
    let args: ServerVersionInternalCommandCmdArgs

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        return io.out("\(aeroSpaceAppVersion) \(gitHash)")
    }
}
