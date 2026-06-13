extension String {
    // Input: "  foo   bar ". Output: ["foo", "bar"]
    // Input "foo 'bar baz'". Output ["foo", "bar baz"]
    public func splitArgs() -> Parsed<[String]> {
        var result: [String] = []
        var arg: String = ""
        var state: State = .parseArgWhitespaceSeparator
        for char in self {
            switch state { // State machine
                case .parseArgWhitespaceSeparator:
                    if char.isQuote {
                        state = .parseArg(quoteChar: char) // Open quotes
                    } else if !char.isWhitespace {
                        state = .parseArg(quoteChar: nil) // Start bare word
                        arg.append(char)
                    }
                case .parseArg(quoteChar: char): // Close quotes
                    result.append(arg)
                    arg = ""
                    state = .parseArgWhitespaceSeparator
                case .parseArg(quoteChar: nil) where char.isWhitespace: // End bare word
                    result.append(arg)
                    state = .parseArgWhitespaceSeparator
                    arg = ""
                case .parseArg(quoteChar: nil) where char.isQuote: // A quote inside bare word
                    return .failure("Unexpected quote \(char) in argument '\(arg)'")
                case .parseArg: // Yet another character of a bare word
                    arg.append(char)
            }
        }
        switch state {
            case .parseArg(let quoteChar?): return .failure("Last quote \(quoteChar) isn't closed")
            case .parseArg: result.append(arg)
            case .parseArgWhitespaceSeparator: break
        }
        return .success(result)
    }
}

extension Character {
    fileprivate var isQuote: Bool { self == "\'" || self == "\"" }
}

private enum State {
    case parseArg(quoteChar: Character?)
    case parseArgWhitespaceSeparator
}

extension [String] {
    public func joinArgs() -> String {
        self.map { arg in
            let containsWhitespaces = arg.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
            let containsSingleQuote = arg.contains("'")
            let containsDoubleQuote = arg.contains("\"")
            return switch true {
                case containsDoubleQuote && !containsSingleQuote:
                    arg.singleQuoted
                case containsSingleQuote && !containsDoubleQuote:
                    arg.doubleQuoted
                case containsSingleQuote && containsDoubleQuote:
                    // Technically shouldn't be possible according to splitArgs
                    arg.replacing("'", with: "\\'").replacing("\"", with: "\\\"").doubleQuoted
                case containsWhitespaces:
                    arg.singleQuoted
                default:
                    arg
            }
        }.joined(separator: " ")
    }
}
