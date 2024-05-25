public typealias Parsed<T> = Result<T, String>
extension String: Error {} // Make it possible to use String in Result

public extension String {
    func trim() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func quoted(with char: String) -> String { char + self + char }
    var singleQuoted: String { "'" + self + "'" }
    var doubleQuoted: String { "\"" + self + "\"" }
}

public extension [[String]] {
    func toPaddingTable(columnSeparator: String = " | ") -> [String] {
        let pads: [Int] = transposed.map { column in column.map { $0.count }.max()! }
        return self.map { (row: [String]) in
            zip(row, pads)
                .map { (elem: String, pad: Int) in
                    elem.padding(toLength: pad, withPad: " ", startingAt: 0)
                }
                .joined(separator: columnSeparator)
        }
    }
}

private extension [[String]] {
    var transposed: [[String]] {
        if isEmpty {
            return []
        }
        let table: [[String]] = self
        var result: [[String]] = []
        for columnIndex in 0... {
            if columnIndex < table.first!.count {
                result += [table.map { row in row[columnIndex] }]
            } else {
                break
            }
        }
        return result
    }
}

public extension String {
    func interpolate(with variables: [String: String]) -> (result: String, errors: [String]) {
        var mode: InterpolationParserState = .stringLiteral
        var result = ""
        var errors: [String] = []
        for char: Character? in (Array(self) + [nil]) {
            switch (mode, char) { // State machine
                case (.stringLiteral, "$"):
                    mode = .dollarEncountered
                case (.stringLiteral, _):
                    if let char {
                        result.append(char)
                    }
                case (.dollarEncountered, "{"):
                    mode = .interpolatedValue("")
                case (.dollarEncountered, "$"):
                    result.append("$")
                case (.dollarEncountered, _):
                    result.append("$")
                    if let char {
                        result.append(char)
                    }
                    mode = .stringLiteral
                case (.interpolatedValue(let value), "}"):
                    if let expanded = variables[value] {
                        result.append(expanded)
                    } else {
                        errors.append("Env variable '\(value)' isn't presented in AeroSpace.app Env vars, or not available for interpolation (because it's mutated)")
                    }
                    mode = .stringLiteral
                case (.interpolatedValue(let value), "{"):
                    return ("", ["Can't parse '\(value + "{")' environment variable (Open curly brace is invalid character)"])
                case (.interpolatedValue(let value), "$"):
                    return ("", ["Can't parse '\(value + "$")' environment variable (Dollar is invalid character)"])
                case (.interpolatedValue(let value), _):
                    if let char {
                        mode = .interpolatedValue(value + String(char))
                    } else {
                        return ("", ["Unbalanced curly braces"])
                    }
            }
        }
        return (result, errors)
    }
}

private enum InterpolationParserState {
    case stringLiteral, dollarEncountered
    case interpolatedValue(String)
}
