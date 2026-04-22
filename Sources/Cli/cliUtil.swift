import Common
import Darwin
import Foundation

let cliClientVersionAndHash: String = "\(aeroshiftAppVersion) \(gitHash)"

func hasStdin() -> Bool {
    isatty(STDIN_FILENO) != 1
}
