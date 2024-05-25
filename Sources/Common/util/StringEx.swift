public typealias Parsed<T> = Result<T, String>
extension String: Error {} // Make it possible to use String in Result
extension [String]: Error {} // Make it possible to use [String] in Result

public extension String {
    func trim() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func quoted(with char: String) -> String { char + self + char }
    var singleQuoted: String { "'" + self + "'" }
    var doubleQuoted: String { "\"" + self + "\"" }
}

public extension [[String]] {
    func toPaddingTable(columnSeparator: String = " | ", padLastColumn: Bool = false) -> [String] {
        let pads: [Int] = transposed.map { column in column.map { $0.count }.max()! }
        return self.map { (row: [String]) in
            zip(row.enumerated(), pads)
                .map { (elem: (Int, String), pad: Int) in
                    padLastColumn || elem.0 != row.count - 1
                        ? elem.1.padding(toLength: pad, withPad: " ", startingAt: 0)
                        : elem.1
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
    func interpolate(with variables: [String: String], interpolationChar: Character = "$") -> Result<String, [String]> {
        interpolationTokens()
            .mapError { [$0] }
            .flatMap { tokens in
                tokens.mapAllOrFailures { token in
                    switch token {
                        case .literal(let literal): .success(literal)
                        case .value(let value): variables[value].flatMap(Result.success)
                            ?? .failure("Env variable '\(value)' isn't presented in AeroSpace.app env vars, " +
                                "or not available for interpolation (because it's mutated)")
                    }
                }
            }
            .map { $0.joined(separator: "") }
    }

    func interpolationTokens(interpolationChar: Character = "$") -> Result<[StringInterToken], String> {
        var mode: InterpolationParserState = .stringLiteral
        var result: [StringInterToken] = []
        var literal: String = ""
        for char: Character? in (Array(self) + [nil]) {
            switch (mode, char) { // State machine
                case (.stringLiteral, interpolationChar):
                    mode = .dollarEncountered
                case (.stringLiteral, _):
                    if let char {
                        literal.append(char)
                    } else {
                        result.append(.literal(literal))
                    }
                case (.dollarEncountered, "{"):
                    mode = .interpolatedValue("")
                    result.append(.literal(literal))
                    literal = ""
                case (.dollarEncountered, interpolationChar):
                    literal.append(interpolationChar)
                case (.dollarEncountered, _):
                    literal.append(interpolationChar)
                    if let char {
                        literal.append(char)
                    } else {
                        result.append(.literal(literal))
                    }
                    mode = .stringLiteral
                case (.interpolatedValue(let value), "}"):
                    result.append(.value(value))
                    mode = .stringLiteral
                case (.interpolatedValue(let value), "{"):
                    return .failure("Can't parse '\(value + "{")' inside interpolation (Open curly brace is invalid character)")
                case (.interpolatedValue(let value), interpolationChar):
                    return .failure("Can't parse '\(value + .init(interpolationChar))' inside interpolation ('\(interpolationChar)' is disallowed character)")
                case (.interpolatedValue(let value), _):
                    if let char {
                        mode = .interpolatedValue(value + .init(char))
                    } else {
                        return .failure("Unbalanced curly braces")
                    }
            }
        }
        return .success(result.filter { $0 != .literal("") })
    }
}

public enum StringInterToken: Equatable {
    case literal(String)
    case value(String)
}

private enum InterpolationParserState {
    case stringLiteral, dollarEncountered
    case interpolatedValue(String)
}
