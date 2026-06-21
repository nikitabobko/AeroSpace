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

protocol CmdIo: AnyObject {
    var stdout: [String] { get set }
    var stderr: [String] { get set }
    func readStdin() -> String
}

extension CmdIo {
    @discardableResult func out(_ msg: String) -> IoSideEffect { stdout.append(msg); return .instance }
    @discardableResult func err(_ msg: String) -> IoSideEffect { stderr.append(msg); return .instance }
    @discardableResult func out(_ msg: [String]) -> IoSideEffect { stdout += msg; return .instance }
    // periphery:ignore
    @discardableResult func err(_ msg: [String]) -> IoSideEffect { stderr += msg; return .instance }
}

final class CmdIoImpl: CmdIo {
    private var stdin: CmdStdin
    var stdout: [String] = []
    var stderr: [String] = []

    init(stdin: consuming CmdStdin) { self.stdin = stdin }
    func readStdin() -> String { stdin.readAll() }

    static var emptyStdinIgnoringOut: CmdIo { CmdIoImpl(stdin: .emptyStdin) }
}

final class CmdIoForwardingStdin: CmdIo {
    private var stdin: CmdIo
    var stdout: [String] = []
    var stderr: [String] = []

    init(stdin: CmdIo) { self.stdin = stdin }
    func readStdin() -> String { stdin.readStdin() }
}

struct CmdResult: Equatable {
    let stdout: [String]
    let stderr: [String]
    let exitCode: Int32ExitCode
}
