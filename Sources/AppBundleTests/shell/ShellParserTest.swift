@testable import AppBundle
import Common
import XCTest

final class ShellParserTest: XCTestCase {
    func testParser() {
        assertSucc("echo foo && bar".parseShell(), .and(.cmd("echo", "foo"), "bar"))
        assertSucc("foo && bar || baz".parseShell(), .or(.and("foo", "bar"), "baz"))
        assertSucc("foo || bar && baz".parseShell(), .or("foo", .and("bar", "baz")))
        assertSucc("echo '' \"\"".parseShell(), .cmd(["echo", "", ""]))
    }

    func testParserEmpty() {
        assertSucc("".parseShell(), .empty)
        assertSucc("   ".parseShell(), .empty)
        assertSucc("\t".parseShell(), .empty)
        assertSucc("# only a comment".parseShell(), .empty)
    }

    func testParserSingleCommand() {
        assertSucc("foo".parseShell(), "foo")
        assertSucc("foo bar".parseShell(), .cmd("foo", "bar"))
        assertSucc("foo bar baz".parseShell(), .cmd(["foo", "bar", "baz"]))
    }

    func testParserPipe() {
        assertSucc("foo | bar".parseShell(), .pipe("foo", "bar"))
        assertSucc("a | b | c".parseShell(), .pipe(["a", "b", "c"]))
        assertSucc("a b | c d".parseShell(), .pipe(.cmd("a", "b"), .cmd("c", "d")))
    }

    func testParserAndChain() {
        assertSucc("a && b && c".parseShell(), .and(["a", "b", "c"]))
    }

    func testParserOrChain() {
        assertSucc("a || b || c".parseShell(), .or(["a", "b", "c"]))
    }

    func testParserPrecedence() {
        assertSucc("a | b && c".parseShell(), .and(.pipe("a", "b"), "c"))
        assertSucc("a && b | c".parseShell(), .and("a", .pipe("b", "c")))
        assertSucc("a | b || c".parseShell(), .or(.pipe("a", "b"), "c"))
        assertSucc("a || b | c".parseShell(), .or("a", .pipe("b", "c")))
        assertSucc("a | b && c || d".parseShell(), .or(.and(.pipe("a", "b"), "c"), "d"))
    }

    func testParserSemicolon() {
        assertSucc("foo; bar".parseShell(), .seq("foo", "bar"))
        assertSucc("a;b".parseShell(), .seq("a", "b"))
        assertSucc("a;;b".parseShell(), .seq("a", "b"))
        assertSucc("a; b; c".parseShell(), .seq(["a", "b", "c"]))
        assertSucc("a && b; c || d".parseShell(), .seq(.and("a", "b"), .or("c", "d")))
        assertSucc("a | b; c | d".parseShell(), .seq(.pipe("a", "b"), .pipe("c", "d")))
    }

    func testParserParens() {
        assertSucc("(foo)".parseShell(), "foo")
        assertSucc("(foo bar)".parseShell(), .cmd("foo", "bar"))
        assertSucc("((foo))".parseShell(), "foo")
        assertSucc("(a; b)".parseShell(), .seq("a", "b"))
        assertSucc("(a && b) || c".parseShell(), .or(.and("a", "b"), "c"))
        assertSucc("a && (b || c)".parseShell(), .and("a", .or("b", "c")))
        assertSucc("(a || b) && (c || d)".parseShell(), .and(.or("a", "b"), .or("c", "d")))
    }

    func testParserFailNewlineWithoutSemicolon() {
        assertFail("foo\nbar".parseShell(), "Line 2 Column 1: Please use explicit semicolon in place of a newline")
        assertSucc("foo bar;\nbaz".parseShell(), .seq(.cmd("foo", "bar"), "baz"))
    }

    func testParserTrailingOperator() {
        assertSucc("foo;".parseShell(), .cmd("foo"))
        assertSucc("foo\n\n".parseShell(), .cmd("foo"))
        assertSucc("foo\n\n;\n".parseShell(), .cmd("foo"))

        assertFail("foo &&".parseShell(), "Line 1 Column 7: Expected at least one word. Got: End of input")
        assertFail("foo ||".parseShell(), "Line 1 Column 7: Expected at least one word. Got: End of input")
        assertFail("foo |".parseShell(), "Line 1 Column 6: Expected at least one word. Got: End of input")
    }

    func testParserFailLeadingOperator() {
        assertFail("&& foo".parseShell(), "Line 1 Column 1: Expected at least one word. Got: &&")
        assertFail("|| foo".parseShell(), "Line 1 Column 1: Expected at least one word. Got: ||")
        assertFail("| foo".parseShell(), "Line 1 Column 1: Expected at least one word. Got: |")
        assertFail(";".parseShell(), "Line 1 Column 1: Expected at least one word. Got: ;")
    }

    func testParserFailParens() {
        assertFail("()".parseShell(), "Line 1 Column 2: Expected at least one word. Got: )")
        assertFail("(foo".parseShell(), "Line 1 Column 5: Expected ')'. Got: 'End of input'")
        assertFail("foo)".parseShell(), "Line 1 Column 4: Unexpected token ')'")
        // Per the grammar, a parenthesized group is a Pipe-level atom and cannot itself be piped.
        assertFail("(foo) | bar".parseShell(), "Line 1 Column 7: Unexpected token '|'")
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
