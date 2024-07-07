import XCTest
import Common
@testable import AppBundle

final class AeroShellTest: XCTestCase {
    func testParse() {
        let a = cmd("a")
        let b = cmd("b")
        let c = cmd("c")
        let d = cmd("d")
        let e = cmd("e")
        let f = cmd("f")
        let backslash = "\\"
        let space = " "

        assertEquals("\"foo \(backslash)\" bar \(backslash)\(backslash)\(backslash)\(backslash)\" bar".parseShell().getOrThrow(), cmd("foo \" bar \(backslash)\(backslash)", "bar"))
        assertEquals("  ".parseShell().getOrThrow(), .empty)
        assertEquals("a | b && c | d".parseShell().getOrThrow(), .and(.pipe(a, b), .pipe(c, d)))
        assertEquals("foo && bar || a && baz".parseShell().getOrThrow(), .or(.and(cmd("foo"), cmd("bar")), .and(cmd("a"), cmd("baz"))))
        assertEquals("foo a b; bar duh\n baz bro".parseShell().getOrThrow(), .seqV(cmd("foo", "a", "b"), cmd("bar", "duh"), cmd("baz", "bro")))
        assertEquals("(a || b) && (c || d)".parseShell().getOrThrow(), .and(.or(a, b), .or(c, d)))
        assertEquals("""
            a # comment 1
            b && c # comment 2
            d; # comment 3
            """.parseShell().getOrThrow(), .seqV(a, .and(b, c), d))
        assertEquals("""
            a && b # comment 1
                # comment 2
                || c && d
            """.parseShell().getOrThrow(), .or(.and(a, b), .and(c, d)))
        assertEquals("""
            a \(backslash)\(space)
                b c \(backslash) # comment 2
                d && e \(backslash)
                && f
            """.parseShell().getOrThrow(), .and(.and(cmd("a", "b", "c", "d"), e), f))
        assertEquals("""
            echo "hi $(foo bar)"
            """.parseShell().getOrThrow(),
            .args([.text("echo"), .concatV(.text("hi "), .interpolation(cmd("foo", "bar")))])
        )
        assertEquals("\"\\n\\t\\$\"".parseShell().getOrThrow(), cmd("\n\t$"))
        assertEquals("echo 'single quoted \\n'".parseShell().getOrThrow(), cmd("echo", "single quoted \\n"))

        assertFailure("\"\\f\"".parseShell())
        assertFailure("echo <".parseShell())
        assertFailure("echo \"\"\"\"".parseShell())
        assertFailure("echo \"foo \(backslash)\"".parseShell())
        assertFailure("|| foo".parseShell())
        assertFailure("a && (b || c) foo".parseShell())
    }
}

func cmd(_ args: String...) -> Shell<String> { .args(args.map(ShellString.text)) }
extension Shell {
    static func seqV(_ seq: Shell<T>...) -> Shell<T> { .seq(seq) }
}

extension ShellString {
    static func concatV(_ fragments: ShellString<T>...) -> ShellString<T> { .concat(fragments) }
}
