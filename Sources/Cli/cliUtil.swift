import Common
import Darwin
import Foundation

let cliClientVersionAndHash: String = "\(aeroShiftAppVersion) \(gitHash)"

func hasStdin() -> Bool {
    isatty(STDIN_FILENO) != 1
}
