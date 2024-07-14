class CmdStdin {
    private var input: String = ""
    init(_ input: String) {
        self.input = input
    }
    static var emptyStdin: CmdStdin { .init("") }

    func readAll() -> String {
        let result = input
        input = ""
        return result
    }
}

class CmdIo {
    private var stdin: CmdStdin
    var stdout: [String] = []
    var stderr: [String] = []

    init(stdin: CmdStdin) { self.stdin = stdin }

    @discardableResult func out(_ msg: String) -> Bool { stdout.append(msg); return true }
    @discardableResult func err(_ msg: String) -> Bool { stderr.append(msg); return false }
    @discardableResult func out(_ msg: [String]) -> Bool { stdout += msg; return true }
    @discardableResult func err(_ msg: [String]) -> Bool { stderr += msg; return false }

    func readStdin() -> String { stdin.readAll() }
}

struct CmdResult {
    let stdout: [String]
    let stderr: [String]
    let exitCode: Int32
}
