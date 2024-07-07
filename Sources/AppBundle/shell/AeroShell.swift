import AeroShellParserGenerated
import Antlr4
import Common

/// Use the following technique for quick grammar testing:
///     source .deps/python-venv/bin/activate.fish
///     echo "foo bar" | antlr4-parse ./grammar/AeroShellLexer.g4 ./grammar/AeroShellParser.g4 root -gui
extension String {
    func parseShell() -> Result<RawShell, String> {
        let stream = ANTLRInputStream(self)
        let lexer = AeroShellLexer(stream)
        let errorsCollector = ErrorListenerCollector()
        lexer.addErrorListener(errorsCollector)
        let tokenStream = CommonTokenStream(lexer)
        let parser: AeroShellParser
        switch Result(catching: { try AeroShellParser(tokenStream) }) {
            case .success(let x): parser = x
            case .failure(let msg):
                return .failure(msg.localizedDescription)
        }
        parser.addErrorListener(errorsCollector)
        let root: AeroShellParser.RootContext
        switch Result(catching: { try parser.root() }) {
            case .success(let x): root = x
            case .failure(let msg):
                return .failure(msg.localizedDescription)
        }
        if !errorsCollector.errors.isEmpty {
            return .failure(errorsCollector.errors.joinErrors())
        }
        return root.program().map { $0.toTyped() } ?? .success(.empty)
    }
}

class ErrorListenerCollector: BaseErrorListener {
    var errors: [String] = []
    override func syntaxError<T>(
        _ recognizer: Recognizer<T>,
        _ offendingSymbol: AnyObject?,
        _ line: Int,
        _ charPositionInLine: Int,
        _ msg: String,
        _ e: AnyObject?
    ) {
        errors.append("Syntax error at \(line):\(charPositionInLine) \(msg)")
    }
}

extension AeroShellParser.ProgramContext {
    func toTyped() -> Result<RawShell, String> {
        if let x = self as? AeroShellParser.NotContext {
            return x.program().toTyped("not node: nil child")
        }
        if let x = self as? AeroShellParser.PipeContext {
            return binaryNode(Shell.pipe, x.program(0), x.program(1))
        }
        if let x = self as? AeroShellParser.AndContext {
            return binaryNode(Shell.and, x.program(0), x.program(1))
        }
        if let x = self as? AeroShellParser.OrContext {
            return binaryNode(Shell.or, x.program(0), x.program(1))
        }
        if let x = self as? AeroShellParser.SeqContext {
            let seq = x.program()
            return switch seq.count {
                case 0: .failure("seq node: 0 children")
                case 1: seq.first!.toTyped()
                default: seq.mapAllOrFailures { $0.toTyped() }.mapError { $0.joinErrors() }.map(Shell.seq)
            }
        }
        if let x = self as? AeroShellParser.ParensContext {
            return x.program().toTyped("parens node: nil childe")
        }
        if let x = self as? AeroShellParser.ArgsContext {
            return x.arg().mapAllOrFailures { $0.toTyped() }.mapError { $0.joinErrors() }.map(Shell.args)
        }
        error("Unknown node type: \(self)")
    }
}


extension AeroShellParser.ArgContext {
    func toTyped() -> Result<ShellString<String>, String> {
        if let x = self as? AeroShellParser.WordContext {
            return .success(.text(x.getText()))
        }
        if let x = self as? AeroShellParser.DQuotedStringContext {
            let seq = x.dStringFragment()
            return switch seq.count {
                case 1: seq.first!.toTyped()
                default:
                    seq.mapAllOrFailures { $0.toTyped() }.mapError { $0.joinErrors() }.map(ShellString.concatOptimized)
            }
        }
        if let x = self as? AeroShellParser.SQuotedStringContext {
            return .success(.text(String(x.getText().dropFirst(1).dropLast(1))))
        }
        if let x = self as? AeroShellParser.SubstitutionContext {
            return x.program().toTyped("substitution node: nil child").map(ShellString.interpolation)
        }
        error("Unknown node type: \(self)")
    }
}

extension AeroShellParser.DStringFragmentContext {
    func toTyped() -> Result<ShellString<String>, String> {
        if let x = self as? AeroShellParser.EscapeSequenceContext {
            return switch x.getText() {
                case "\\n": .success(.text("\n"))
                case "\\t": .success(.text("\t"))
                case "\\$": .success(.text("$"))
                case "\\\"": .success(.text("\""))
                case "\\\\": .success(.text("\\"))
                default: .failure("Unknown ESCAPE_SEQUENCE '\(x.getText())'")
            }
        }
        if let x = self as? AeroShellParser.TextContext {
            return .success(.text(x.getText()))
        }
        if let x = self as? AeroShellParser.InterpolationContext {
            return x.program().toTyped("interpolation node: nil child").map(ShellString.interpolation)
        }
        error("Unknown node type: \(self)")
    }
}

private func binaryNode(
    _ op: (RawShell, RawShell) -> RawShell,
    _ a: AeroShellParser.ProgramContext?,
    _ b: AeroShellParser.ProgramContext?
) -> Result<RawShell, String> {
    a.toTyped("binary node: nil child 0").combine { b.toTyped("binary node: nil child 1") }.map(op)
}

extension Result {
    func combine<T>(_ other: () -> Result<T, Failure>) -> Result<(Success, T), Failure> {
        flatMap { a in
            other().flatMap { b in
                .success((a, b))
            }
        }
    }
}

extension Result where Success == AeroShellParser.ProgramContext, Failure == String {
    func toTyped() -> Result<RawShell, String> { flatMap { $0.toTyped() } }
}

private extension Optional where Wrapped == AeroShellParser.ProgramContext {
    func toTyped(_ msg: String) -> Result<RawShell, String> { orFailure(msg).toTyped() }
}

class CmdMutableState {
    var stdin: String
    var env: [String: String]

    init(stdin: String, pwd: String) {
        self.stdin = stdin
        self.env = config.execConfig.envVariables
        self.env["PWD"] = pwd
    }
}

struct CmdOut {
    let stdout: [String]
    let exitCode: Int

    static func succ(_ stdout: [String]) -> CmdOut { CmdOut(stdout: stdout, exitCode: 0) }
    static func fail(_ stdout: [String]) -> CmdOut { CmdOut(stdout: stdout, exitCode: 1) }
}

// protocol AeroShell {
//     func run(_ state: CmdMutableState) -> CmdOut
// }
// extension [String] : AeroShell {
//     func run(_ state: CmdMutableState) -> CmdOut { .succ(self) }
// }

extension Shell: Equatable where T: Equatable {}
typealias AeroShell = Shell<any Command>
typealias RawShell = Shell<String>
indirect enum Shell<T> {
    case args([ShellString<T>])
    case empty

    // Listed in precedence order
    case not(Shell<T>)
    case pipe(Shell<T>, Shell<T>)
    case and(Shell<T>, Shell<T>)
    case or(Shell<T>, Shell<T>)
    case seq([Shell<T>])
}

extension ShellString: Equatable where T: Equatable {}
enum ShellString<T> {
    case text(String)
    case interpolation(Shell<T>)
    case concat([ShellString<T>])

    static func concatOptimized(_ fragments: [ShellString<T>]) -> ShellString<T> {
        var result: [ShellString<T>] = []
        var current: String = ""
        _concatOptimized(fragments, &result, &current)
        if !current.isEmpty {
            result.append(.text(current))
        }
        return result.singleOrNil() ?? .concat(result)
    }

    private static func _concatOptimized(
        _ fragments: [ShellString<T>],
        _ result: inout [ShellString<T>],
        _ current: inout String
    ) {
        for fragment in fragments {
            switch fragment {
                case .text(let text): current += text
                case .concat(let newFragments): _concatOptimized(newFragments, &result, &current)
                case .interpolation:
                    if !current.isEmpty {
                        result.append(.text(current))
                        current = ""
                    }
                    result.append(fragment)
            }
        }
    }
}
