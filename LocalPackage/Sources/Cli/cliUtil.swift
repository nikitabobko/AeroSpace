import Foundation
import Darwin
import Common

#if DEBUG
let appId: String = "bobko.debug.aerospace"
#else
let appId: String = "bobko.aerospace"
#endif

private var stderr = FileHandle.standardError

public func prettyError(_ message: String = "") -> Never {
    prettyErrorT(message)
}

public func prettyErrorT<T>(_ message: String = "") -> T {
    printStderr(message)
    exit(1)
}

func printStderr(_ msg: String) {
    print(msg, to: &stderr)
}

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        let data = Data(string.utf8)
        self.write(data)
    }
}

let cliClientVersionAndHash: String = "\(aeroSpaceAppVersion) \(gitHash)"

extension String {
    func trim() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

func initCli() {
    struct CliClientTerminationHandler: TerminationHandler {
        func beforeTermination() {} // nothing to do in CLI
    }

    _terminationHandler = CliClientTerminationHandler()
}

func isATty(_ fd: Int32) -> Bool {
    isatty(fd) == 1
}
