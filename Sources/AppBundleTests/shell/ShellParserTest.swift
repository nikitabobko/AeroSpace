@testable import AppBundle
import Common
import XCTest

final class ShellParserTest: XCTestCase {
    func testParser() {
        assertSucc("echo foo && bar".lexAndParseShell(), .and(.cmd("echo", "foo"), "bar"))
        assertSucc("foo && bar || baz".lexAndParseShell(), .or(.and("foo", "bar"), "baz"))
        assertSucc("foo || bar && baz".lexAndParseShell(), .or("foo", .and("bar", "baz")))
        assertSucc("echo '' \"\"".lexAndParseShell(), .cmd(["echo", "", ""]))

        let a = """
            foo ||
                bar
            """
        assertFail(a.lexAndParseShell(), "Line 1 Column 7: Expected at least one word. Got: \n")
        let b = """
            foo
                || bar
            """
        assertFail(b.lexAndParseShell(), "Line 1 Column 4: Please escape newline with backslash character.")
        let c = """
            foo || \\
                bar || \\ # comment
                baz \\
                || duh \\ # comment
                || qux
            """
        assertSucc(c.lexAndParseShell(), .or(["foo", "bar", "baz", "duh", "qux"]))
    }

    func testParserEmpty() {
        assertSucc("".lexAndParseShell(), .empty)
        assertSucc("   ".lexAndParseShell(), .empty)
        assertSucc("\t".lexAndParseShell(), .empty)
        assertSucc("# only a comment".lexAndParseShell(), .empty)
    }

    func testParserSingleCommand() {
        assertSucc("foo".lexAndParseShell(), "foo")
        assertSucc("foo bar".lexAndParseShell(), .cmd("foo", "bar"))
        assertSucc("foo bar baz".lexAndParseShell(), .cmd(["foo", "bar", "baz"]))
    }

    func testParserPipe() {
        assertSucc("foo | bar".lexAndParseShell(), .pipe("foo", "bar"))
        assertSucc("a | b | c".lexAndParseShell(), .pipe(["a", "b", "c"]))
        assertSucc("a b | c d".lexAndParseShell(), .pipe(.cmd("a", "b"), .cmd("c", "d")))
    }

    func testParserAndChain() {
        assertSucc("a && b && c".lexAndParseShell(), .and(["a", "b", "c"]))
    }

    func testParserOrChain() {
        assertSucc("a || b || c".lexAndParseShell(), .or(["a", "b", "c"]))
    }

    func testParserPrecedence() {
        assertSucc("a | b && c".lexAndParseShell(), .and(.pipe("a", "b"), "c"))
        assertSucc("a && b | c".lexAndParseShell(), .and("a", .pipe("b", "c")))
        assertSucc("a | b || c".lexAndParseShell(), .or(.pipe("a", "b"), "c"))
        assertSucc("a || b | c".lexAndParseShell(), .or("a", .pipe("b", "c")))
        assertSucc("a | b && c || d".lexAndParseShell(), .or(.and(.pipe("a", "b"), "c"), "d"))
    }

    func testParserSemicolon() {
        assertSucc("foo; bar".lexAndParseShell(), .seq("foo", "bar"))
        assertSucc("a;b".lexAndParseShell(), .seq("a", "b"))
        assertSucc("a;;b".lexAndParseShell(), .seq("a", "b"))
        assertSucc("a; b; c".lexAndParseShell(), .seq(["a", "b", "c"]))
        assertSucc("a && b; c || d".lexAndParseShell(), .seq(.and("a", "b"), .or("c", "d")))
        assertSucc("a | b; c | d".lexAndParseShell(), .seq(.pipe("a", "b"), .pipe("c", "d")))
    }

    func testParserParens() {
        assertSucc("(foo)".lexAndParseShell(), "foo")
        assertSucc("(foo bar)".lexAndParseShell(), .cmd("foo", "bar"))
        assertSucc("((foo))".lexAndParseShell(), "foo")
        assertSucc("(a; b)".lexAndParseShell(), .seq("a", "b"))
        assertSucc("(a && b) || c".lexAndParseShell(), .or(.and("a", "b"), "c"))
        assertSucc("a && (b || c)".lexAndParseShell(), .and("a", .or("b", "c")))
        assertSucc("(a || b) && (c || d)".lexAndParseShell(), .and(.or("a", "b"), .or("c", "d")))
    }

    func testParserFailNewlineWithoutSemicolon() {
        assertFail("foo\nbar".lexAndParseShell(), "Line 2 Column 1: Please use explicit semicolon in place of a newline")
        assertSucc("foo bar;\nbaz".lexAndParseShell(), .seq(.cmd("foo", "bar"), "baz"))
    }

    func testParserTrailingOperator() {
        assertSucc("foo;".lexAndParseShell(), .cmd("foo"))
        assertSucc("foo\n\n".lexAndParseShell(), .cmd("foo"))
        assertSucc("foo\n\n;\n".lexAndParseShell(), .cmd("foo"))

        assertFail("foo &&".lexAndParseShell(), "Line 1 Column 7: Expected at least one word. Got: End of input")
        assertFail("foo ||".lexAndParseShell(), "Line 1 Column 7: Expected at least one word. Got: End of input")
        assertFail("foo |".lexAndParseShell(), "Line 1 Column 6: Expected at least one word. Got: End of input")
    }

    func testParserFailLeadingOperator() {
        assertFail("&& foo".lexAndParseShell(), "Line 1 Column 1: Expected at least one word. Got: &&")
        assertFail("|| foo".lexAndParseShell(), "Line 1 Column 1: Expected at least one word. Got: ||")
        assertFail("| foo".lexAndParseShell(), "Line 1 Column 1: Expected at least one word. Got: |")
        assertFail(";".lexAndParseShell(), "Line 1 Column 1: Expected at least one word. Got: ;")
    }

    func testParserFailParens() {
        assertFail("()".lexAndParseShell(), "Line 1 Column 2: Expected at least one word. Got: )")
        assertFail("(foo".lexAndParseShell(), "Line 1 Column 5: Expected ')'. Got: 'End of input'")
        assertFail("foo)".lexAndParseShell(), "Line 1 Column 4: Unexpected token ')'")
        // Per the grammar, a parenthesized group is a Pipe-level atom and cannot itself be piped.
        assertFail("(foo) | bar".lexAndParseShell(), "Line 1 Column 7: Unexpected token '|'")
    }

    func testBuildDescription() {
        func render(_ shell: Shell<[String]>) -> String { shell.buildDescription { $0.joined(separator: " ") } }

        assertEquals(render(.or(.and("a", "b"), "c")), "a && b || c")
        assertEquals(render(.seq(.or("a", "b"), .and("c", "d"))), "a || b; c && d")
        assertEquals(render(.and(.pipe("a", "b"), "c")), "a | b && c")

        assertEquals(render(.and(.or("a", "b"), "c")), "(a || b) && c")
        assertEquals(render(.and("a", .or("b", "c"))), "a && (b || c)")
        assertEquals(render(.pipe(.seq("a", "b"), "c")), "(a; b) | c")
        assertEquals(render(.or(.seq("a", "b"), "c")), "(a; b) || c")
        assertEquals(render(.and(.or("a", "b"), .or("c", "d"))), "(a || b) && (c || d)")

        assertEquals(render("foo"), "foo")
        assertEquals(render(.and(["a", "b", "c"])), "a && b && c")
        assertEquals(render(.empty), "")
    }
}

extension Shell {
    static func or(_ a: Self, _ b: Self) -> Self { .or([a, b]) }
    static func and(_ a: Self, _ b: Self) -> Self { .and([a, b]) }
    static func pipe(_ a: Self, _ b: Self) -> Self { .pipe([a, b]) }
    static func seq(_ a: Self, _ b: Self) -> Self { .seq([a, b]) }

    static func cmd(_ a: String, _ b: String) -> Self where T == [String] { .cmd([a, b]) }
    static func cmd(_ a: String) -> Self where T == [String] { .cmd([a]) }
}

extension Shell: ExpressibleByUnicodeScalarLiteral where T == [String] {}
extension Shell: ExpressibleByExtendedGraphemeClusterLiteral where T == [String] {}
extension Shell: ExpressibleByStringLiteral where T == [String] {
    public init(stringLiteral value: String) { self = .cmd([value]) }
}
