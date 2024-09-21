public typealias StringLogicalSegments = [StringLogicalSegment]
public extension StringLogicalSegments {
    static func < (lhs: Self, rhs: Self) -> Bool {
        for (a, b) in zip(lhs, rhs) {
            if a < b {
                return true
            }
            if a > b {
                return false
            }
        }
        if lhs.count != rhs.count {
            return lhs.count < rhs.count
        }
        return false
    }
}

public enum StringLogicalSegment: Comparable, Equatable {
    case string(String)
    case number(Int)

    public static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
            case (.string(let a), .string(let b)): a < b
            case (.number(let a), .number(let b)): a < b
            case (.number, _): true
            case (.string, _): false
        }
    }
}

public extension String {
    func toLogicalSegments() -> StringLogicalSegments {
        var currentSegment: String = ""
        var isPrevNumber: Bool = false // Initial value doesn't matter
        var result: [String] = []
        for char in self {
            let isCurNumber = Int(char.description) != nil
            if isCurNumber != isPrevNumber && !currentSegment.isEmpty {
                result.append(currentSegment)
                currentSegment = ""
            }
            currentSegment.append(char)
            isPrevNumber = isCurNumber
        }
        if !currentSegment.isEmpty {
            result.append(currentSegment)
        }
        return result.map { Int($0).flatMap(StringLogicalSegment.number) ?? .string($0) }
    }
}
