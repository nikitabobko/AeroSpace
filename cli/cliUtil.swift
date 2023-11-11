import Foundation
import Darwin

#if DEBUG
let appId: String = "bobko.debug.aerospace"
#else
let appId: String = "bobko.aerospace"
#endif

public func error(_ message: String = "") -> Never {
    errorT(message)
}

public func errorT<T>(_ message: String = "") -> T {
    print(message)
    exit(1)
}

let cliClientVersionAndHash: String = "\(cliClientVersion) \(gitHash)"
