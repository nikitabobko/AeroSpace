import XCTest
import Common
@testable import AppBundle

final class ShellTest: XCTestCase {
    let a = cmd("a")
    let b = cmd("b")
    let c = cmd("c")
    let d = cmd("d")
    let e = cmd("e")
    let f = cmd("f")
    let g = cmd("g")
    let k = cmd("k")
    let backslash = "\\"
    let space = " "

    func testParse() {
        assertSucc("echo \"foo \\\" bar \(backslash)\(backslash)\(backslash)\(backslash)\" bar".parseShell(), cmd("echo", "foo \" bar \(backslash)\(backslash)", "bar"))
        assertSucc("  \n".parseShell(), .empty)
        assertSucc("a | b && c | d".parseShell(), .and(.pipe(a, b), .pipe(c, d)))
        assertSucc("foo && bar || a && baz".parseShell(), .or(.and(cmd("foo"), cmd("bar")), .and(cmd("a"), cmd("baz"))))
        assertSucc("foo a b; bar duh\n baz bro".parseShell(), .seqV(cmd("foo", "a", "b"), cmd("bar", "duh"), cmd("baz", "bro")))
        assertSucc("(a || b) && (c || d)".parseShell(), .and(.or(a, b), .or(c, d)))
        assertSucc("""
            a # comment 1
            b && c # comment 2
            d; # comment 3
            """.parseShell(), .seqV(a, .and(b, c), d))
        assertEquals("""
            a && b # comment 1
                # comment 2
                # comment 3
                || c && d
            """.parseShell(), .success(.or(.and(a, b), .and(c, d))))
        assertSucc("""
            a \(backslash)\(space)
                b c \(backslash) # comment 2
                d && e \(backslash)
                && f
            """.parseShell(), .and(.and(cmd("a", "b", "c", "d"), e), f))
        assertSucc(
            """
            echo "hi \\n $(foo bar)"
            """.parseShell(),
            .args([.text("echo"), .concatV(.text("hi \n "), .interpolation(cmd("foo", "bar")))])
        )
        assertSucc("echo \"\\n\\t\\$\"".parseShell(), cmd("echo", "\n\t$"))
        assertSucc("echo 'single quoted \\n'".parseShell(), cmd("echo", "single quoted \\n"))

        assertFail("echo \"\\f\"".parseShell(), "ERROR: ERROR: Unknown ESCAPE_SEQUENCE '\\f'")
        assertFail("echo <".parseShell(), "ERROR: Syntax error at 1:5 extraneous input '<' expecting <EOF>. Please put the character/word in quotes, if you want to use it as an argument")
        assertFail("echo `".parseShell(), "ERROR: Syntax error at 1:5 extraneous input '`' expecting <EOF>. Please put the character/word in quotes, if you want to use it as an argument")
        assertFail("echo \"\"\"\"".parseShell(), "ERROR: Triple quotes are reserved for future use. Please put spaces in between if you meant separate args")
        assertFail("echo do".parseShell(), "ERROR: Syntax error at 1:5 extraneous input 'do' expecting <EOF>. DO is a reserved keyword. Please, put quotes around it, if you want to use it as an argument")
        assertFail("echo \"foo \(backslash)\"".parseShell(), "ERROR: Syntax error at 1:12 Unbalanced quotes")
        assertFail("a; (b".parseShell(), "ERROR: Syntax error at 1:5 Unbalanced parenthesis")
        assertFail("a; (b))".parseShell(), "ERROR: Syntax error at 1:7 Unbalanced parenthesis")
        assertFail("|| foo".parseShell())
        assertFail("a && (b || c) foo".parseShell())
    }

    func testParseIf() {
        assertSucc("if a then b else c end".parseShell(), .ifElse((a, b), elseB: c))
        assertSucc("""
            if a && b then
                c
            else
                d
            end
            """.parseShell(), .ifElse((.and(a, b), c), elseB: d))
        assertSucc("""
            if a && b then
                c
            end
            """.parseShell(), .ifElse((.and(a, b), c), elseB: nil))
        assertSucc("""
            if a && b then
                c
            elif d then
                e
            elif f then
                g
            end
            """.parseShell(), .ifElse((.and(a, b), c), (d, e), (f, g), elseB: nil))
        assertSucc("""
            if a && b then
            end
            """.parseShell(), .ifElse((.and(a, b), nil), elseB: nil))
        assertSucc("""
            if a && b then
            else
                c
            end
            """.parseShell(), .ifElse((.and(a, b), nil), elseB: c))
        assertSucc("""
            echo foo

            echo bar;;

            if a && b then
                c
            elif d then
                e
            elif f then
                g
                k
            end
            """.parseShell(), .seqV(cmd("echo", "foo"), cmd("echo", "bar"), .ifElse((.and(a, b), c), (d, e), (f, .seqV(g, k)), elseB: nil)))
    }
}

func cmd(_ args: String...) -> Shell<String> { .args(args.map(ShellString.text)) }
extension Shell {
    static func seqV(_ seq: Shell<T>...) -> Shell<T> { .seq(seq) }
}

extension ShellString {
    static func concatV(_ fragments: ShellString<T>...) -> ShellString<T> { .concat(fragments) }
}
