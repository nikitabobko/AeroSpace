import Common

/// Declarative, hierarchical description of the desired container structure of a workspace.
///
/// Syntax:
/// ```
/// h_tiles[1@0.6, v_tiles[others]]
/// ```
/// - `h_tiles[...]`/`v_tiles[...]` — tiling containers with the corresponding orientation
/// - `1`, `2`, ... — placeholders for windows. Windows are assigned to placeholders in ascending order of the numbers
/// - `others` — swallows all the windows that aren't assigned to placeholders. Must appear exactly once
/// - `@0.6` — optional relative weight of a container, a placeholder or `others`
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
        var parser = SkeletonParser(source: source)
        do {
            return .success(LayoutSkeleton(root: try parser.parseSkeleton()))
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
        return result.sorted()
    }
}

private struct SkeletonParser {
    private let chars: [Character]
    private var index: Int = 0

    init(source: String) {
        chars = Array(source)
    }

    mutating func parseSkeleton() throws -> LayoutSkeleton.Container {
        let root = try parseContainer()
        skipWhitespace()
        guard isAtEnd else { throw error("Unexpected trailing characters") }
        try validate(root)
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
        let orientation: Orientation = switch identifier {
            case "h_tiles": .h
            case "v_tiles": .v
            default: throw error("Expected 'h_tiles' or 'v_tiles'. Got: \(identifier.singleQuoted)")
        }
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

    private func validate(_ container: LayoutSkeleton.Container) throws {
        var placeholders: Set<Int> = []
        var othersCount = 0
        func walk(_ container: LayoutSkeleton.Container) throws {
            for child in container.children {
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
        }
        try walk(container)
        if othersCount != 1 {
            throw LayoutSkeletonParseError(
                description: "'others' must appear exactly once. Found: \(othersCount). " +
                    "'others' is needed to guarantee that no window is lost after normalization",
            )
        }
    }

    private func error(_ message: String) -> LayoutSkeletonParseError {
        LayoutSkeletonParseError(description: "\(message) at offset \(index)")
    }
}
