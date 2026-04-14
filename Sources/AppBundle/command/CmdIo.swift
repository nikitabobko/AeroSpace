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

    @discardableResult func out(_ msg: String) -> IoSideEffect { stdout.append(msg); return .instance }
    @discardableResult func err(_ msg: String) -> IoSideEffect { stderr.append(msg); return .instance }
    @discardableResult func out(_ msg: [String]) -> IoSideEffect { stdout += msg; return .instance }
    // periphery:ignore
    @discardableResult func err(_ msg: [String]) -> IoSideEffect { stderr += msg; return .instance }

    func readStdin() -> String { stdin.readAll() }
}

struct CmdResult: Equatable {
    let stdout: [String]
    let stderr: [String]
    let exitCode: Int32ExitCode
}
