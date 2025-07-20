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
                    if char == "\"" || char == "\'" {
                        state = .parseArg(quoteChar: char)
                    } else if !char.isWhitespace {
                        state = .parseArg(quoteChar: nil)
                        arg.append(char)
                    }
                case .parseArg(let quoteChar):
                    if quoteChar == char {
                        result.append(arg)
                        arg = ""
                        state = .parseArgWhitespaceSeparator
                    } else if quoteChar == nil && char.isWhitespace {
                        result.append(arg)
                        state = .parseArgWhitespaceSeparator
                        arg = ""
                    } else if quoteChar == nil && char.isQuote {
                        return .failure("Unexpected quote \(char) in argument '\(arg)'")
                    } else {
                        arg.append(char)
                    }
            }
        }
        if case .parseArg(let quoteChar) = state {
            if let quoteChar {
                return .failure("Last quote \(quoteChar) isn't closed")
            } else {
                result.append(arg)
            }
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
            let containsWhitespaces = $0.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
            let containsSingleQuote = $0.contains("'")
            let containsDoubleQuote = $0.contains("\"")
            return switch true {
                case containsDoubleQuote && !containsSingleQuote:
                    $0.quoted(with: "'")
                case containsSingleQuote && !containsDoubleQuote:
                    $0.quoted(with: "\"")
                case containsSingleQuote && containsDoubleQuote:
                    // Technically shouldn't be possible according to splitArgs
                    $0.replacing("'", with: "\\'").replacing("\"", with: "\\\"").quoted(with: "\"")
                case containsWhitespaces:
                    $0.quoted(with: "'")
                default:
                    $0
            }
        }.joined(separator: " ")
    }
}
