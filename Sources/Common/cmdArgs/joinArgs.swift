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
                    // Technically shouldn't be possible according to shell lexer & parser
                    arg.replacing("'", with: "\\'").replacing("\"", with: "\\\"").doubleQuoted
                case containsWhitespaces:
                    arg.singleQuoted
                default:
                    arg
            }
        }.joined(separator: " ")
    }
}
