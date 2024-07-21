import Foundation
import Darwin
import Common

#if DEBUG
let appId: String = "bobko.debug.aerospace"
#else
let appId: String = "bobko.aerospace"
#endif


public func prettyError(_ message: String = "") -> Never {
    prettyErrorT(message)
}

public func prettyErrorT<T>(_ message: String = "") -> T {
    printStderr(message)
    exit(1)
}

let cliClientVersionAndHash: String = "\(aeroSpaceAppVersion) \(gitHash)"

func hasStdin() -> Bool {
    isatty(STDIN_FILENO) != 1
}
