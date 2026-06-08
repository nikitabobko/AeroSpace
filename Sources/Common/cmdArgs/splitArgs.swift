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
        self.map {
            lazy var containsWhitespaces = $0.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
            let containsSingleQuote = $0.contains("'")
            let containsDoubleQuote = $0.contains("\"")
            return switch true {
                case containsDoubleQuote && !containsSingleQuote:
                    $0.singleQuoted
                case containsSingleQuote && !containsDoubleQuote:
                    $0.doubleQuoted
                case containsSingleQuote && containsDoubleQuote:
                    // Technically shouldn't be possible according to splitArgs
                    $0.replacing("'", with: "\\'").replacing("\"", with: "\\\"").doubleQuoted
                case containsWhitespaces:
                    $0.singleQuoted
                default:
                    $0
            }
        }.joined(separator: " ")
    }
}
