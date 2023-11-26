import Foundation
import Darwin

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

let cliClientVersionAndHash: String = "\(cliClientVersion) \(gitHash)"
