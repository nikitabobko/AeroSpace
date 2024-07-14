import Antlr4
import Common
import ShellParserGenerated

typealias TK = ShellParser.Tokens

/// Use the following technique for quick grammar testing:
///     source .deps/python-venv/bin/activate.fish
///     echo "foo bar" | antlr4-parse ./grammar/ShellLexer.g4 ./grammar/ShellParser.g4 root -gui
extension String {
    func parseShell() -> Result<RawShell, String> {
        let stream = ANTLRInputStream(self)
        let lexer = ShellLexer(stream)
        let errorsCollector = ErrorListenerCollector()
        lexer.addErrorListener(errorsCollector)
        let tokenStream = CommonTokenStream(lexer)
        let parser: ShellParser
        switch Result(catching: { try ShellParser(tokenStream) }) {
            case .success(let x): parser = x
            case .failure(let msg):
                return .failure(msg.localizedDescription)
        }
        parser.addErrorListener(errorsCollector)
        let root: ShellParser.RootContext
        switch Result(catching: { try parser.root() }) {
            case .success(let x): root = x
            case .failure(let msg):
                return .failure(msg.localizedDescription)
        }
        if !errorsCollector.errors.isEmpty {
            return .failure(errorsCollector.errors.joinErrors())
        }
        return root.cmds().map { $0.toTyped() } ?? .success(.empty)
    }
}

let keywords = [TK.DO, TK.THEN, TK.IF, TK.END, TK.ELSE, TK.SWITCH, TK.IN, TK.CASE, TK.WHILE, TK.DEFER, TK.FOR, TK.CATCH].map(\.rawValue)

class ErrorListenerCollector: BaseErrorListener {
    var errors: [String] = []
    override func syntaxError(
        _ recognizer: Recognizer<some Any>,
        _ offendingSymbol: AnyObject?,
        _ line: Int,
        _ charPositionInLine: Int,
        _ msg: String,
        _ e: AnyObject?
    ) {
        let offendingToken = (offendingSymbol as? Token)?.getType()
        if offendingToken == TK.TRIPLE_QUOTE.rawValue {
            errors.append("Triple quotes are reserved for future use. Please put spaces in between if you meant separate args")
            return
        }
        let helper = if let offendingToken, keywords.contains(offendingToken),
                        let name = ShellParser.VOCABULARY.getSymbolicName(offendingToken)
        {
            ". \(name) is a reserved keyword. Please, put quotes around it, if you want to use it as an argument"
        } else if offendingToken == TK.ANY.rawValue {
            ". Please put the character/word in quotes, if you want to use it as an argument"
        } else {
            ""
        }
        errors.append("Syntax error at \(line):\(charPositionInLine) \(msg)\(helper)")
    }
}

extension ShellParser.CmdsContext {
    func toTyped() -> Result<RawShell, String> {
        if let x = self as? ShellParser.SeqContext {
            return x.cmd().toTyped("seq node: nil cmd")
                .combine { x.cmds().mapAllOrFailures { $0.toTyped() }.mapError { $0.joinErrors() } }
                .flatMap {
                    let seq = [$0.0] + $0.1
                    return switch seq.count {
                        case 0: .failure("seq node: 0 children")
                        case 1: .success(seq.first!)
                        default: .success(Shell.seq(seq))
                    }
                }
        }
        if let x = self as? ShellParser.IfElseContext {
            return Result { try parseIfElse(x) }.mapError { $0 as! String }
        }
        return .failure("Unknown node type: \(self)")
    }
}

private func parseIfElse(_ ifElse: ShellParser.IfElseContext) throws -> Shell<String> {
    var lastCond: Shell<String>? = nil
    var branches: [Branch<String>] = []
    var elseVisited = false
    guard let children = ifElse.children else { throw "switch if: nil children" }
    for child in children {
        if let child = child as? ShellParser.CmdContext {
            if let lastCond { branches.append(Branch(cond: lastCond, then: nil)) }
            lastCond = try child.toTyped().get()
        } else if let child = child as? ShellParser.CmdsContext {
            if elseVisited {
                return .ifElse(IfElse(branches: branches, elseBranch: try child.toTyped().get()))
            } else {
                try branches.append(Branch(cond: lastCond ?? throwT("nil lastCond"), then: child.toTyped().get()))
                lastCond = nil
            }
        } else if let child = child as? TerminalNode,
                  child.getSymbol()?.getType() == TK.ELSE.rawValue
        {
            elseVisited = true
            if let lastCond { branches.append(Branch(cond: lastCond, then: nil)) }
            lastCond = nil
        }
    }
    if let lastCond {
        if elseVisited { throw "ifElse node: wtf" }
        return .ifElse(IfElse(branches: [Branch(cond: lastCond, then: nil)], elseBranch: nil))
    }
    return .ifElse(IfElse(branches: branches, elseBranch: nil))
}

extension ShellParser.CmdContext {
    func toTyped() -> Result<RawShell, String> {
        if let x = self as? ShellParser.PipeContext {
            return binaryNode(Shell.pipe, x.cmd(0), x.cmd(1))
        }
        if let x = self as? ShellParser.AndContext {
            return binaryNode(Shell.and, x.cmd(0), x.cmd(1))
        }
        if let x = self as? ShellParser.OrContext {
            return binaryNode(Shell.or, x.cmd(0), x.cmd(1))
        }
        if let x = self as? ShellParser.ParensContext {
            return x.cmds().toTyped("parens node: nil childe")
        }
        if let x = self as? ShellParser.ArgsContext {
            return (x.WORD()?.getText()).orFailure("args node: nil first word").map(ShellString.text)
                .combine { x.arg().mapAllOrFailures { $0.toTyped() }.mapError { $0.joinErrors() } }
                .map { [$0.0] + $0.1 }
                .map(Shell.args)
        }
        return .failure("Unknown node type: \(self)")
    }
}

extension ShellParser.ArgContext {
    func toTyped() -> Result<ShellString<String>, String> {
        if let x = self as? ShellParser.WordContext {
            return .success(.text(x.getText()))
        }
        if let x = self as? ShellParser.DQuotedStringContext {
            return x.dStringFragment().mapAllOrFailures { $0.toTyped() }
                .mapError { $0.joinErrors() }.map(ShellString.concatOptimized)
        }
        if let x = self as? ShellParser.SQuotedStringContext {
            return .success(.text(String(x.getText().dropFirst(1).dropLast(1))))
        }
        if let x = self as? ShellParser.SubstitutionContext {
            return x.cmds().toTyped("substitution node: nil child").map(ShellString.interpolation)
        }
        return .failure("Unknown node type: \(self)")
    }
}

extension ShellParser.DStringFragmentContext {
    func toTyped() -> Result<ShellString<String>, String> {
        if let x = self as? ShellParser.EscapeSequenceContext {
            return switch x.getText() {
                case "\\n": .success(.text("\n"))
                case "\\t": .success(.text("\t"))
                case "\\$": .success(.text("$"))
                case "\\\"": .success(.text("\""))
                case "\\\\": .success(.text("\\"))
                default: .failure("Unknown ESCAPE_SEQUENCE '\(x.getText())'")
            }
        }
        if let x = self as? ShellParser.TextContext {
            return .success(.text(x.getText()))
        }
        if let x = self as? ShellParser.InterpolationContext {
            return x.cmds().toTyped("interpolation node: nil child").map(ShellString.interpolation)
        }
        return .failure("Unknown node type: \(self)")
    }
}

private func binaryNode(
    _ op: (RawShell, RawShell) -> RawShell,
    _ a: ShellParser.CmdContext?,
    _ b: ShellParser.CmdContext?
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

extension Result where Success == ShellParser.CmdContext, Failure == String {
    func toTyped() -> Result<RawShell, String> { flatMap { $0.toTyped() } }
}
extension Result where Success == ShellParser.CmdsContext, Failure == String {
    func toTyped() -> Result<RawShell, String> { flatMap { $0.toTyped() } }
}

private extension ShellParser.CmdContext? {
    func toTyped(_ msg: String) -> Result<RawShell, String> { orFailure(msg).toTyped() }
}
private extension ShellParser.CmdsContext? {
    func toTyped(_ msg: String) -> Result<RawShell, String> { orFailure(msg).toTyped() }
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

    case ifElse(IfElse<T>)

    // Listed in precedence order
    case pipe(Shell<T>, Shell<T>)
    case and(Shell<T>, Shell<T>)
    case or(Shell<T>, Shell<T>)
    case seq([Shell<T>])

    static func ifElse(_ branches: (Shell<T>, Shell<T>?)..., elseB: Shell<T>?) -> Shell<T> {
        .ifElse(IfElse(branches: branches.map { Branch(cond: $0.0, then: $0.1) }, elseBranch: elseB))
    }
}

extension IfElse: Equatable where T: Equatable {}
struct IfElse<T> {
    let branches: [Branch<T>]
    let elseBranch: Shell<T>?
}

extension Branch: Equatable where T: Equatable {}
struct Branch<T> {
    let cond: Shell<T>
    let then: Shell<T>?
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
