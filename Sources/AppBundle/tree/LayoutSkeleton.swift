import Common

/// Declarative, hierarchical description of the desired container structure of a workspace.
///
/// Indented syntax (recommended, the same shape as the proposal in #260):
/// ```
/// h_tiles
///   1 @0.6
///   v_tiles
///     others
/// ```
///
/// Inline syntax (shorthand for a single line):
/// ```
/// h_tiles[1@0.6, v_tiles[others]]
/// ```
///
/// - `h_tiles`/`v_tiles` — tiling containers with the corresponding orientation
/// - `1`, `2`, ... — placeholders for windows. Windows are assigned to placeholders in ascending order of the numbers
/// - `others` — swallows the windows that aren't assigned to placeholders. Must appear exactly once
/// - `@0.6` — optional weight of a container, a placeholder or `others`
///
/// The skeleton is a *normalization*: AeroSpace reshapes the workspace on every layout pass and collapses unfilled
/// placeholders. Users never change the skeleton at runtime, they only change the set of windows.
struct LayoutSkeleton: Equatable, Sendable {
    let root: Container

    indirect enum Node: Equatable, Sendable {
        case container(Container)
        case placeholder(Int, weight: Double? = nil)
        case others(weight: Double? = nil)
    }

    struct Container: Equatable, Sendable {
        let orientation: Orientation
        var children: [Node] = []
        var weight: Double? = nil
    }
}

struct LayoutSkeletonParseError: Error, Equatable, CustomStringConvertible {
    let description: String
}

extension LayoutSkeleton {
    static func parse(_ source: String) -> Result<LayoutSkeleton, LayoutSkeletonParseError> {
        do {
            if source.contains("[") {
                var parser = InlineSkeletonParser(source: source)
                return .success(LayoutSkeleton(root: try parser.parseSkeleton()))
            } else {
                var parser = try IndentedSkeletonParser(source: source)
                return .success(LayoutSkeleton(root: try parser.parseSkeleton()))
            }
        } catch let error as LayoutSkeletonParseError {
            return .failure(error)
        } catch {
            return .failure(LayoutSkeletonParseError(description: "\(error)"))
        }
    }
}

extension LayoutSkeleton.Container {
    var placeholdersSorted: [Int] {
        var result: [Int] = []
        func walk(_ container: LayoutSkeleton.Container) {
            for child in container.children {
                switch child {
                    case .placeholder(let number, _): result.append(number)
                    case .container(let container): walk(container)
                    case .others: break
                }
            }
        }
        walk(self)
        return result
    }
}

// MARK: - Validation

private func validateSkeleton(_ root: LayoutSkeleton.Container) throws {
    var placeholders: Set<Int> = []
    var othersCount = 0
    func walk(_ container: LayoutSkeleton.Container) throws {
        var specifiedWeights: [Double] = []
        var unspecifiedWeightsCount = 0
        for child in container.children {
            let weight: Double? = switch child {
                case .container(let container): container.weight
                case .placeholder(_, let weight): weight
                case .others(let weight): weight
            }
            if let weight {
                specifiedWeights.append(weight)
            } else {
                unspecifiedWeightsCount += 1
            }
            switch child {
                case .container(let container):
                    try walk(container)
                case .placeholder(let number, _):
                    if !placeholders.insert(number).inserted {
                        throw LayoutSkeletonParseError(description: "Duplicate placeholder \(number)")
                    }
                case .others:
                    othersCount += 1
            }
        }
        if unspecifiedWeightsCount > 0 && specifiedWeights.reduce(0, +) >= 1 {
            throw LayoutSkeletonParseError(
                description: "The weights of the siblings with an explicit weight must sum to less than 1 " +
                    "because \(unspecifiedWeightsCount) sibling(s) have no weight and share the rest of the axis",
            )
        }
    }
    try walk(root)
    if othersCount != 1 {
        throw LayoutSkeletonParseError(
            description: "'others' must appear exactly once. Found: \(othersCount). " +
                "'others' is needed to guarantee that no window is lost after normalization",
        )
    }
}

// MARK: - Inline syntax

private struct InlineSkeletonParser {
    private let chars: [Character]
    private var index: Int = 0

    init(source: String) {
        chars = Array(source)
    }

    mutating func parseSkeleton() throws -> LayoutSkeleton.Container {
        let root = try parseContainer()
        skipWhitespace()
        guard isAtEnd else { throw error("Unexpected trailing characters") }
        try validateSkeleton(root)
        return root
    }

    private var isAtEnd: Bool { index >= chars.count }

    private var currentChar: Character? { isAtEnd ? nil : chars[index] }

    private mutating func skipWhitespace() {
        while let char = currentChar, char.isWhitespace {
            index += 1
        }
    }

    private mutating func parseContainer() throws -> LayoutSkeleton.Container {
        skipWhitespace()
        let identifier = parseIdentifier()
        let orientation = try orientationOf(identifier)
        skipWhitespace()
        try expect("[")
        var children: [LayoutSkeleton.Node] = []
        while true {
            skipWhitespace()
            if currentChar == "]" {
                index += 1
                break
            }
            children.append(try parseNode())
            skipWhitespace()
            if currentChar == "," {
                index += 1
                continue
            }
            if currentChar == "]" {
                index += 1
                break
            }
            throw error("Expected ',' or ']'")
        }
        if children.isEmpty {
            throw error("'\(identifier)' must contain at least one child")
        }
        let weight = try parseOptionalWeight()
        return LayoutSkeleton.Container(orientation: orientation, children: children, weight: weight)
    }

    private mutating func parseNode() throws -> LayoutSkeleton.Node {
        skipWhitespace()
        guard let char = currentChar else { throw error("Unexpected end of input") }
        if char.isNumber {
            let number = try parseUnsignedInteger()
            if number == 0 {
                throw error("Placeholder numbers start from 1")
            }
            return .placeholder(number, weight: try parseOptionalWeight())
        }
        let savedIndex = index
        let identifier = parseIdentifier()
        switch identifier {
            case "others": return .others(weight: try parseOptionalWeight())
            case "h_tiles", "v_tiles":
                index = savedIndex
                return .container(try parseContainer())
            default: throw error("Unexpected token \(identifier.singleQuoted)")
        }
    }

    private mutating func parseIdentifier() -> String {
        let start = index
        while let char = currentChar, char.isLetter || char == "_" {
            index += 1
        }
        return String(chars[start ..< index])
    }

    private mutating func parseUnsignedInteger() throws -> Int {
        let start = index
        while let char = currentChar, char.isNumber {
            index += 1
        }
        guard let number = Int(String(chars[start ..< index])) else {
            throw error("Can't parse number")
        }
        return number
    }

    private mutating func parseOptionalWeight() throws -> Double? {
        skipWhitespace()
        guard currentChar == "@" else { return nil }
        index += 1
        skipWhitespace()
        let start = index
        while let char = currentChar, char.isNumber || char == "." {
            index += 1
        }
        let raw = String(chars[start ..< index])
        guard let weight = Double(raw), weight > 0 else {
            throw error("Weight must be a positive number. Got: \(raw.singleQuoted)")
        }
        return weight
    }

    private mutating func expect(_ char: Character) throws {
        guard currentChar == char else { throw error("Expected '\(char)'") }
        index += 1
    }

    private func error(_ message: String) -> LayoutSkeletonParseError {
        LayoutSkeletonParseError(description: "\(message) at offset \(index)")
    }
}

// MARK: - Indented syntax

private struct IndentedSkeletonParser {
    private struct Line {
        let indent: Int
        let text: String
        let number: Int // 1-based line number for error messages
    }

    private let lines: [Line]
    private var index: Int = 0

    init(source: String) throws {
        var lines: [Line] = []
        for (index, rawLine) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let rawLine = String(rawLine)
            let text = rawLine.trimmingCharacters(in: .whitespaces)
            if text.isEmpty {
                continue
            }
            if rawLine.contains("\t") {
                throw LayoutSkeletonParseError(
                    description: "Tabs aren't allowed for indentation at line \(index + 1). Use spaces",
                )
            }
            let indent = rawLine.prefix(while: { $0 == " " }).count
            lines.append(Line(indent: indent, text: text, number: index + 1))
        }
        self.lines = lines
    }

    mutating func parseSkeleton() throws -> LayoutSkeleton.Container {
        guard let first = lines.first else {
            throw LayoutSkeletonParseError(description: "The layout is empty")
        }
        let root = try parseContainer(indent: first.indent)
        guard index == lines.count else {
            throw error("Unexpected indentation", line: lines[index])
        }
        try validateSkeleton(root)
        return root
    }

    private mutating func parseContainer(indent: Int) throws -> LayoutSkeleton.Container {
        let line = lines[index]
        let (token, weight) = try parseToken(line)
        let orientation = try orientationOf(token)
        index += 1
        var children: [LayoutSkeleton.Node] = []
        var childrenIndent: Int? = nil
        while index < lines.count, lines[index].indent > indent {
            if let childrenIndent, lines[index].indent != childrenIndent {
                throw error("Inconsistent indentation", line: lines[index])
            }
            childrenIndent = lines[index].indent
            children.append(try parseNode(indent: lines[index].indent))
        }
        if children.isEmpty {
            throw error("'\(token)' must contain at least one child", line: line)
        }
        return LayoutSkeleton.Container(orientation: orientation, children: children, weight: weight)
    }

    private mutating func parseNode(indent: Int) throws -> LayoutSkeleton.Node {
        let line = lines[index]
        let (token, weight) = try parseToken(line)
        if token == "others" {
            index += 1
            return .others(weight: weight)
        }
        if let number = Int(token) {
            if number == 0 {
                throw error("Placeholder numbers start from 1", line: line)
            }
            index += 1
            return .placeholder(number, weight: weight)
        }
        return .container(try parseContainer(indent: indent))
    }

    private func parseToken(_ line: Line) throws -> (token: String, weight: Double?) {
        guard let atIndex = line.text.firstIndex(of: "@") else {
            return (line.text, nil)
        }
        let token = line.text[..<atIndex].trimmingCharacters(in: .whitespaces)
        let rawWeight = line.text[line.text.index(after: atIndex)...].trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty else { throw error("Expected a token before '@'", line: line) }
        guard let weight = Double(rawWeight), weight > 0 else {
            throw error("Weight must be a positive number. Got: \(rawWeight.singleQuoted)", line: line)
        }
        return (token, weight)
    }

    private func error(_ message: String, line: Line) -> LayoutSkeletonParseError {
        LayoutSkeletonParseError(description: "\(message) at line \(line.number): \(line.text.singleQuoted)")
    }
}

private func orientationOf(_ token: String) throws -> Orientation {
    switch token {
        case "h_tiles": .h
        case "v_tiles": .v
        default:
            throw LayoutSkeletonParseError(
                description: "Expected 'h_tiles' or 'v_tiles'. Got: \(token.singleQuoted)",
            )
    }
}
