import Common

// Root = Seq? EndOfInput
//
// EndOfInput = /$/
//
// Seq = Or ((";" | "\n")+ Or?)*
//
// Or = And ("||" And)*
//
// And = Pipe ("&&" Pipe)*
//
// Pipe
//   = "(" Seq ")"
//   | Cmd ("|" Cmd)*
//
// Cmd = Word+

extension String {
    func lexAndParseShell() -> ResOrStr<Shell<[String]>> {
        self.shellLexerTokens().flatMap(AppBundle.parseShell)
    }
}

func parseShell(_ tokens: [LexerToken]) -> ResOrStr<Shell<[String]>> {
    Result { () throws(String) in
        switch tokens.singleOrNil() {
            case let single? where single.payload == .end:
                return .empty
            default:
                var index = 0
                let result = try parseShellSeq(&index, tokens)
                let token = tokens[index]
                if token.payload != .end {
                    throw "\(token.location): Unexpected token \(token.payload.description.singleQuoted)"
                }
                return result
        }
    }
}

private func parseShellSeq(_ index: inout Int, _ tokens: [LexerToken]) throws(String) -> Shell<[String]> {
    var cur = [try parseShellOr(&index, tokens)]
    while true {
        if tokens[index].payload != .semicolon && tokens[index].payload != .newline { break }
        var sawASemicolon = false
        while tokens[index].payload == .semicolon || tokens[index].payload == .newline {
            sawASemicolon = sawASemicolon || tokens[index].payload == .semicolon
            index += 1
        }
        if canStartOrParsing(tokens[index].payload) {
            if !sawASemicolon { // todo: [compatibility] remove this diagnostic after a while
                throw "\(tokens[index].location): Please use explicit semicolon in place of a newline"
            }
            cur.append(try parseShellOr(&index, tokens))
        }
    }
    return .newCompound(cur, Shell.seq)
}

// FIRST(Or) = FIRST(And) = FIRST(Pipe) = { "(" } ∪ FIRST(Cmd) = { "(" } ∪ { Word } = { "(", Word }
private func canStartOrParsing(_ token: LexerToken.Payload) -> Bool {
    switch token {
        case .word, .lParen: true
        case .end, .and, .or, .pipe, .rParen, .semicolon, .newline: false
    }
}

private func parseShellOr(_ index: inout Int, _ tokens: [LexerToken]) throws(String) -> Shell<[String]> {
    try binaryOperationParsingLoop(op: .or, recurDescent: parseShellAnd, constructor: Shell.or, &index, tokens)
}

private func parseShellAnd(_ index: inout Int, _ tokens: [LexerToken]) throws(String) -> Shell<[String]> {
    try binaryOperationParsingLoop(op: .and, recurDescent: parseShellPipe, constructor: Shell.and, &index, tokens)
}

private func parseShellPipe(_ index: inout Int, _ tokens: [LexerToken]) throws(String) -> Shell<[String]> {
    if tokens[index].payload == .lParen {
        index += 1
        let result = try parseShellSeq(&index, tokens)
        if tokens[index].payload != .rParen {
            throw "\(tokens[index].location): Expected ')'. Got: \(tokens[index].payload.description.singleQuoted)"
        }
        index += 1
        return result
    } else {
        return try binaryOperationParsingLoop(op: .pipe, recurDescent: parseShellCmd, constructor: Shell.pipe, &index, tokens)
    }
}

private func parseShellCmd(_ index: inout Int, _ tokens: [LexerToken]) throws(String) -> Shell<[String]> {
    var words = [String]()
    loop: while let token = tokens.getOrNil(atIndex: index) {
        switch token.payload {
            case .word(let word):
                words.append(word)
                index += 1
            case _ where words.isEmpty:
                throw "\(token.location): Expected at least one word. Got: \(token.payload)"
            default:
                break loop
        }
    }
    return .cmd(words)
}

private func binaryOperationParsingLoop(
    op: LexerToken.Payload,
    recurDescent: (inout Int, [LexerToken]) throws(String) -> Shell<[String]>,
    constructor: ([Shell<[String]>]) -> Shell<[String]>,
    _ index: inout Int,
    _ tokens: [LexerToken],
) throws(String) -> Shell<[String]> {
    var cur = [try recurDescent(&index, tokens)]
    while let token = tokens.getOrNil(atIndex: index) {
        if token.payload != op { break }
        index += 1
        cur.append(try recurDescent(&index, tokens))
    }
    return .newCompound(cur, constructor)
}
