import Common

extension String {
    public func shellLexerTokens() -> ResOrStr<[LexerToken]> {
        Result { () throws(String) in try _shellLexerTokens(self) }
    }
}

private func _shellLexerTokens(_ str: String) throws(String) -> [LexerToken] {
    var result: [LexerToken] = []
    var word: String = ""
    var state: State = .skipWhitespaces

    var index = 0
    var wordLocation = Location(line: 1, column: 1)
    let array: [Char] = locateChars(Array(str + " ")) // synthetic trailing space to flush the last word

    func flushWord(_ wordKind: WordKind) throws(String) {
        if wordKind == .bare, word != "~=", let reservedChar = word.first(where: { reservedChars.contains($0) }) {
            throw "\(wordLocation): Bare word '\(word)' contains reserved character: \(reservedChar). Please quote the bare word if you want to use the character."
        }
        if wordKind == .quoted || !word.isEmpty {
            result.append(.init(wordLocation, .word(word)))
            word = ""
        }
        state = .skipWhitespaces
    }

    while let char = array.getOrNil(atIndex: index) {
        index += 1
        switch (state, char.value) { // State machine
            case (.comment, "\n"): // End comment
                result.append(.init(char.location, .newline))
                state = .skipWhitespaces
            case (.comment, _): break // Skip comment

            case (.quotedWord(quoteChar: char.value), _): // Close quotes
                try flushWord(.quoted)
                state = .rightAfterQuotedWord
            case (.quotedWord, _): // Yet another character of a quoted word
                word.append(char.value)

            case (.backslash, "#"): // Skip comments after backslash
                while let next = array.getOrNil(atIndex: index), next.value != "\n" { index += 1 }
            case (.backslash, "\n"): state = .skipWhitespaces
            case (.backslash, _) where char.value.isWhitespace: break
            case (.backslash, _): throw "\(char.location): backslash can be followed only by whitespaces, newlines and comments, but it is followed by \(char.value.description.singleQuoted)."

            // All the remaining states below: .skipWhitespaces, .bareWord, or .rightAfterQuotedWord

            case (_, "\n"):
                try flushWord(.bare)
                result.append(.init(char.location, .newline))
            case (.rightAfterQuotedWord, _) where char.value.isWhitespace:
                state = .skipWhitespaces

            case (_, "&") where array.getOrNil(atIndex: index)?.value == "&":
                try flushWord(.bare)
                result.append(.init(char.location, .and))
                index += 1
            case (_, "|") where array.getOrNil(atIndex: index)?.value == "|":
                try flushWord(.bare)
                result.append(.init(char.location, .or))
                index += 1
            case (_, "|"):
                try flushWord(.bare)
                result.append(.init(char.location, .pipe))
            case (_, "\\") where array.getOrNil(atIndex: index)?.value == "#":
                throw "\(char.location): Please put a space between backslash and a comment start"
            case (_, "\\"):
                try flushWord(.bare)
                state = .backslash
            case (_, "#"): // Start comment
                try flushWord(.bare)
                state = .comment
            case (_, ";"):
                try flushWord(.bare)
                result.append(.init(char.location, .semicolon))
            case (_, "("):
                try flushWord(.bare)
                result.append(.init(char.location, .lParen))
            case (_, ")"):
                try flushWord(.bare)
                result.append(.init(char.location, .rParen))

            case (.skipWhitespaces, _) where char.value.isQuote: // Open quotes
                state = .quotedWord(quoteChar: char.value)
                wordLocation = char.location
            case _ where char.value.isQuote:
                throw "\(char.location): Please put a space in front of the quote character."
            case (.rightAfterQuotedWord, _):
                throw "\(char.location): Please put a space after closing quote."

            case (.skipWhitespaces, _) where !char.value.isWhitespace: // Start bare word
                state = .bareWord
                wordLocation = char.location
                word.append(char.value)
            case (.skipWhitespaces, _): break // Skip whitespaces

            case (.bareWord, _) where char.value.isWhitespace: // End bare word
                try flushWord(.bare)
            case (.bareWord, _): // Yet another character of a bare word
                word.append(char.value)
        }
    }
    let endLocation = array.last.orDie().location
    switch state {
        case .comment, .skipWhitespaces, .rightAfterQuotedWord, .backslash, .bareWord: break
        case .quotedWord(let quoteChar):
            throw "\(endLocation): Last quote \(quoteChar) isn't closed."
    }
    result.append(.init(endLocation, .end))
    let binaryOperators: [LexerToken.Payload?] = [.and, .or, .pipe]
    for (index, token) in result.enumerated() {
        if token.payload == .newline && binaryOperators.contains(result.getOrNil(atIndex: index + 1)?.payload) {
            throw "\(token.location): Please escape newline with backslash character."
        }
    }
    return result
}

struct Char {
    let value: Character
    let location: Location
}

private func locateChars(_ chars: [Character]) -> [Char] {
    var result = [Char]()
    var location = Location(line: 1, column: 1)
    for char in chars {
        result.append(Char(value: char, location: location))
        location.column += 1
        if char == "\n" {
            location.line += 1
            location.column = 1
        }
    }
    return result
}

private let reservedChars: Set<Character> = ["(", ")", "$", "~", "&", "?", "*", "!", "\\", "|", "<", ">", "`", "'", "\"", "#", "\n"]

public struct LexerToken: Equatable {
    let location: Location
    let payload: Payload

    public init(_ location: Location, _ payload: Payload) {
        self.location = location
        self.payload = payload
    }

    public enum Payload: Equatable, CustomStringConvertible {
        case end

        case word(String)

        case and // &&
        case or // ||
        case pipe // |

        case lParen // (
        case rParen // )

        case semicolon // ;
        case newline // \n

        public var description: String {
            switch self {
                case .end: "End of input"
                case .and: "&&"
                case .lParen: "("
                case .newline: "\n"
                case .or: "||"
                case .pipe: "|"
                case .rParen: ")"
                case .semicolon: ";"
                case .word(let word): word
            }
        }
    }
}

public struct Location: CustomStringConvertible, Equatable {
    public var line: Int
    public var column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    public var description: String { "Line \(line) Column \(column)" }
}

extension Character {
    fileprivate var isQuote: Bool { self == "'" || self == "\"" }
}

private enum State {
    case comment
    case quotedWord(quoteChar: Character)

    case backslash

    case bareWord
    case skipWhitespaces
    case rightAfterQuotedWord
}

private enum WordKind: Equatable {
    case bare
    case quoted
}
