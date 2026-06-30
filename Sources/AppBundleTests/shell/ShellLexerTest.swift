@testable import AppBundle
import Common
import XCTest

final class ShellLexerTest: XCTestCase {
    func testLexer() {
        assertSucc("echo foo".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "foo"), .end(l: 1, c: 9)])
        assertSucc("echo  foo".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 7, "foo"), .end(l: 1, c: 10)])
        assertSucc("echo 'foo' &&".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "foo"), .and(l: 1, c: 12), .end(l: 1, c: 14)])
        assertSucc("echo 'foo' \\ \n&&".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "foo"), .and(l: 2, c: 1), .end(l: 2, c: 3)])
        assertFail("echo 'foo'\n &&".shellLexerTokens(), "Line 1 Column 11: Please escape newline with backslash character.")
        assertFail("echo 'foo' \n &&".shellLexerTokens(), "Line 1 Column 12: Please escape newline with backslash character.")

        assertSucc("echo ''".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, ""), .end(l: 1, c: 8)])
    }

    func testLexerEmpty() {
        assertSucc("".shellLexerTokens(), [.end(l: 1, c: 1)])
        assertSucc("   ".shellLexerTokens(), [.end(l: 1, c: 4)])
        assertSucc("\t".shellLexerTokens(), [.end(l: 1, c: 2)])
    }

    func testLexerLeadingWhitespace() {
        assertSucc("  echo".shellLexerTokens(), [.word(l: 1, c: 3, "echo"), .end(l: 1, c: 7)])
        assertSucc("\techo\tfoo".shellLexerTokens(), [.word(l: 1, c: 2, "echo"), .word(l: 1, c: 7, "foo"), .end(l: 1, c: 10)])
    }

    func testLexerComments() {
        assertSucc("# hello".shellLexerTokens(), [.end(l: 1, c: 8)])
        assertSucc("echo # comment".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .end(l: 1, c: 15)])
        assertSucc("echo#nospace".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .end(l: 1, c: 13)])
        assertSucc("echo # hi\nfoo".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .newline(l: 1, c: 10), .word(l: 2, c: 1, "foo"), .end(l: 2, c: 4)])
    }

    func testLexerSingleQuotes() {
        assertSucc("echo 'hello world'".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "hello world"), .end(l: 1, c: 19)])
        assertSucc("'foo'".shellLexerTokens(), [.word(l: 1, c: 1, "foo"), .end(l: 1, c: 6)])
        assertSucc("echo 'a\"b'".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "a\"b"), .end(l: 1, c: 11)])
    }

    func testLexerDoubleQuotes() {
        assertSucc("echo \"hello world\"".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "hello world"), .end(l: 1, c: 19)])
        assertSucc("\"foo\"".shellLexerTokens(), [.word(l: 1, c: 1, "foo"), .end(l: 1, c: 6)])
        assertSucc("echo \"it's\"".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "it's"), .end(l: 1, c: 12)])
    }

    func testLexerQuotedNewline() {
        assertSucc("echo 'foo\nbar'".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "foo\nbar"), .end(l: 2, c: 5)])
    }

    func testLexerPipeAndOr() {
        assertSucc("echo foo | bar".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "foo"), .pipe(l: 1, c: 10), .word(l: 1, c: 12, "bar"), .end(l: 1, c: 15)])
        assertSucc("echo foo || bar".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "foo"), .or(l: 1, c: 10), .word(l: 1, c: 13, "bar"), .end(l: 1, c: 16)])
        assertSucc("a|b".shellLexerTokens(), [.word(l: 1, c: 1, "a"), .pipe(l: 1, c: 2), .word(l: 1, c: 3, "b"), .end(l: 1, c: 4)])
        assertSucc("a||b".shellLexerTokens(), [.word(l: 1, c: 1, "a"), .or(l: 1, c: 2), .word(l: 1, c: 4, "b"), .end(l: 1, c: 5)])
        assertSucc("a&&b".shellLexerTokens(), [.word(l: 1, c: 1, "a"), .and(l: 1, c: 2), .word(l: 1, c: 4, "b"), .end(l: 1, c: 5)])
    }

    func testLexerSemicolon() {
        assertSucc("echo a;b".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "a"), .semicolon(l: 1, c: 7), .word(l: 1, c: 8, "b"), .end(l: 1, c: 9)])
        assertSucc("echo foo; echo bar".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "foo"), .semicolon(l: 1, c: 9), .word(l: 1, c: 11, "echo"), .word(l: 1, c: 16, "bar"), .end(l: 1, c: 19)])
    }

    func testLexerParens() {
        assertSucc("(echo)".shellLexerTokens(), [.lParen(l: 1, c: 1), .word(l: 1, c: 2, "echo"), .rParen(l: 1, c: 6), .end(l: 1, c: 7)])
        assertSucc("( echo foo )".shellLexerTokens(), [.lParen(l: 1, c: 1), .word(l: 1, c: 3, "echo"), .word(l: 1, c: 8, "foo"), .rParen(l: 1, c: 12), .end(l: 1, c: 13)])
    }

    func testLexerBackslashLineContinuation() {
        assertSucc("echo \\\n foo".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 2, c: 2, "foo"), .end(l: 2, c: 5)])
        assertSucc("echo \\\nfoo".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 2, c: 1, "foo"), .end(l: 2, c: 4)])
        assertSucc("echo \\ \nfoo".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 2, c: 1, "foo"), .end(l: 2, c: 4)])
    }

    func testLexerMultipleNewlines() {
        assertSucc("\n\n\n".shellLexerTokens(), [.newline(l: 1, c: 1), .newline(l: 2, c: 1), .newline(l: 3, c: 1), .end(l: 4, c: 1)])
        assertSucc("echo foo\necho bar".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "foo"), .newline(l: 1, c: 9), .word(l: 2, c: 1, "echo"), .word(l: 2, c: 6, "bar"), .end(l: 2, c: 9)])
        assertSucc("echo foo\n".shellLexerTokens(), [.word(l: 1, c: 1, "echo"), .word(l: 1, c: 6, "foo"), .newline(l: 1, c: 9), .end(l: 2, c: 1)])
    }

    func testLexerFailUnclosedQuote() {
        assertFail("echo 'foo".shellLexerTokens(), "Line 1 Column 10: Last quote ' isn't closed.")
        assertFail("echo \"foo".shellLexerTokens(), "Line 1 Column 10: Last quote \" isn't closed.")
    }

    func testLexerFailQuoteInMiddleOfWord() {
        assertFail("echo foo'bar'".shellLexerTokens(), "Line 1 Column 9: Please put a space in front of the quote character.")
    }

    func testLexerFailMissingSpaceAfterClosingQuote() {
        assertFail("echo 'foo'bar".shellLexerTokens(), "Line 1 Column 11: Please put a space after closing quote.")
    }

    func testLexerFailReservedChar() {
        assertFail("echo $foo".shellLexerTokens(), "Line 1 Column 6: Bare word '$foo' contains reserved character: $. Please quote the bare word if you want to use the character.")
        assertFail("echo *".shellLexerTokens(), "Line 1 Column 6: Bare word '*' contains reserved character: *. Please quote the bare word if you want to use the character.")
        assertFail("echo ~".shellLexerTokens(), "Line 1 Column 6: Bare word '~' contains reserved character: ~. Please quote the bare word if you want to use the character.")
    }

    func testLexerFailBackslashFollowedByNonWhitespace() {
        assertFail("echo \\a".shellLexerTokens(), "Line 1 Column 7: backslash can be followed only by whitespaces, newlines and comments, but it is followed by 'a'.")
    }

    func testLexerFailBackslashFollowedByComment() {
        assertFail("echo \\#foo".shellLexerTokens(), "Line 1 Column 6: Please put a space between backslash and a comment start")
    }
}

extension LexerToken {
    public static func word(l: Int, c: Int, _ str: String) -> Self { .init(Location(line: l, column: c), .word(str)) }
    public static func and(l: Int, c: Int) -> Self { .init(Location(line: l, column: c), .and) }
    public static func or(l: Int, c: Int) -> Self { .init(Location(line: l, column: c), .or) }
    public static func pipe(l: Int, c: Int) -> Self { .init(Location(line: l, column: c), .pipe) }
    public static func lParen(l: Int, c: Int) -> Self { .init(Location(line: l, column: c), .lParen) }
    public static func rParen(l: Int, c: Int) -> Self { .init(Location(line: l, column: c), .rParen) }
    public static func semicolon(l: Int, c: Int) -> Self { .init(Location(line: l, column: c), .semicolon) }
    public static func end(l: Int, c: Int) -> Self { .init(Location(line: l, column: c), .end) }
    public static func newline(l: Int, c: Int) -> Self { .init(Location(line: l, column: c), .newline) }
}
