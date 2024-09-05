import Common
import Darwin
import Foundation

#if DEBUG
    let appId: String = "bobko.debug.aerospace"
#else
    let appId: String = "bobko.aerospace"
#endif

let cliClientVersionAndHash: String = "\(aeroSpaceAppVersion) \(gitHash)"

func hasStdin() -> Bool {
    isatty(STDIN_FILENO) != 1
}
