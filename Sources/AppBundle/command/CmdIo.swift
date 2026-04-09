import Common

struct CmdStdin: ~Copyable {
    private var input: String = ""
    init(_ input: String) {
        self.input = input
    }
    static var emptyStdin: CmdStdin { .init("") }

    mutating func readAll() -> String {
        let result = input
        input = ""
        return result
    }
}

final class CmdIo {
    private var stdin: CmdStdin
    var stdout: [String] = []
    var stderr: [String] = []

    init(stdin: consuming CmdStdin) { self.stdin = stdin }

    @discardableResult func out<T>(_ msg: String, _ ret: T = BinaryExitCode.succ) -> T { stdout.append(msg); return ret }
    @discardableResult func err<T>(_ msg: String, _ ret: T = BinaryExitCode.fail) -> T { stderr.append(msg); return ret }
    @discardableResult func out<T>(_ msg: [String], _ ret: T = BinaryExitCode.succ) -> T { stdout += msg; return ret }
    // periphery:ignore
    @discardableResult func err<T>(_ msg: [String], _ ret: T = BinaryExitCode.fail) -> T { stderr += msg; return ret }

    func readStdin() -> String { stdin.readAll() }
}

struct CmdResult {
    let stdout: [String]
    let stderr: [String]
    let exitCode: Int32ExitCode
}
